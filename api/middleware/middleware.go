package middleware

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"
)

type contextKey struct{}
type authKey struct{}

// WithUser returns a context carrying the current player's identity (a signed-in
// username or an anonymous guest id).
func WithUser(ctx context.Context, username string) context.Context {
	return context.WithValue(ctx, contextKey{}, username)
}

// Username returns the player identity set by Auth/Player, or "" if absent.
func Username(r *http.Request) string {
	u, _ := r.Context().Value(contextKey{}).(string)
	return u
}

// WithAuth records whether the current player is a signed-in account (true) or
// an anonymous guest (false).
func WithAuth(ctx context.Context, authenticated bool) context.Context {
	return context.WithValue(ctx, authKey{}, authenticated)
}

// Authenticated reports whether the request belongs to a signed-in account.
func Authenticated(r *http.Request) bool {
	a, _ := r.Context().Value(authKey{}).(bool)
	return a
}

// SessionLifetime is how long a login lasts without activity, and how far a
// sliding refresh extends it. Thirty days keeps regular players signed in
// while idle accounts still expire; Login and the refresh below must both use
// it so the DB row and the cookie never drift apart.
const SessionLifetime = 30 * 24 * time.Hour

// sessionRefreshThreshold bounds the extra write to one per week of activity:
// only a session expiring within this window is extended, so ordinary game
// traffic does not pay an UPDATE on every request.
const sessionRefreshThreshold = 7 * 24 * time.Hour

// sessionUser resolves a valid "session" cookie to its username. ok is false
// when there is no cookie, no matching session, or the session has expired.
func sessionUser(db *sql.DB, r *http.Request) (username, token string, expires time.Time, ok bool) {
	cookie, err := r.Cookie("session")
	if err != nil {
		return "", "", time.Time{}, false
	}
	err = db.QueryRow(
		"SELECT username, expires_at FROM sessions WHERE token = $1",
		cookie.Value).Scan(&username, &expires)
	if err != nil || time.Now().After(expires) {
		return "", "", time.Time{}, false
	}
	return username, cookie.Value, expires, true
}

// refreshSession extends a session expiring within the refresh window and
// re-issues its cookie, so active players stay signed in. Failures are silent:
// the current request is already authenticated, and the next one retries.
func refreshSession(db *sql.DB, w http.ResponseWriter, token string, expires time.Time) {
	if time.Until(expires) >= sessionRefreshThreshold {
		return
	}
	newExpiry := time.Now().Add(SessionLifetime)
	if _, err := db.Exec(
		"UPDATE sessions SET expires_at = $1 WHERE token = $2", newExpiry, token); err != nil {
		return
	}
	http.SetCookie(w, &http.Cookie{
		Name:     "session",
		Value:    token,
		Path:     "/",
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   int(SessionLifetime.Seconds()),
	})
}

func Auth(db *sql.DB, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		username, token, expires, ok := sessionUser(db, r)
		if !ok {
			unauthorized(w)
			return
		}
		refreshSession(db, w, token, expires)
		ctx := WithAuth(WithUser(r.Context(), username), true)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// Player identifies the current player for the always-open game routes: a
// signed-in account when a valid session cookie is present, otherwise an
// anonymous guest (see Guest). Signing in switches a browser from its guest
// history to the account's own history and unlocks the vocabulary count.
func Player(db *sql.DB, next http.Handler) http.Handler {
	guest := Guest(next)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if username, token, expires, ok := sessionUser(db, r); ok {
			refreshSession(db, w, token, expires)
			ctx := WithAuth(WithUser(r.Context(), username), true)
			next.ServeHTTP(w, r.WithContext(ctx))
			return
		}
		guest.ServeHTTP(w, r)
	})
}

// Guest lets anyone play without signing in. It identifies a player by an
// anonymous "player" cookie, minting one on first visit, so each browser keeps
// its own game history (the spaced-repetition logic still works per browser).
func Guest(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var id string
		if cookie, err := r.Cookie("player"); err == nil && cookie.Value != "" {
			id = cookie.Value
		} else {
			b := make([]byte, 16)
			rand.Read(b)
			id = "guest_" + hex.EncodeToString(b)
			http.SetCookie(w, &http.Cookie{
				Name:     "player",
				Value:    id,
				Path:     "/",
				HttpOnly: true,
				Secure:   true,
				SameSite: http.SameSiteLaxMode, // first-party: Pages proxies /api to this backend
				MaxAge:   60 * 60 * 24 * 365,   // one year
			})
		}
		ctx := WithAuth(WithUser(r.Context(), id), false)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func unauthorized(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusUnauthorized)
	json.NewEncoder(w).Encode(map[string]string{"error": "authentication required"})
}

// slowRequest is the latency above which Logging flags a request "SLOW". It sits
// above the app's intentionally slow paths — bcrypt login/signup and the external
// TTS call — so only a genuine hot-path regression trips it. That gives a
// no-effort signal, during ordinary use, to run the loadtest/ kit before a
// slowdown reaches users.
const slowRequest = 200 * time.Millisecond

func Logging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r) // call the actual handler
		d := time.Since(start)
		if d > slowRequest {
			log.Printf("SLOW %s %s (%s)", r.Method, r.URL.Path, d)
		} else {
			log.Printf("%s %s (%s)", r.Method, r.URL.Path, d)
		}
	})
}

// CORS reflects the request's Origin when it is in the allowed list. Because
// the app sends credentials, "*" is not permitted — a specific origin must be
// echoed back, so multiple front-ends are supported via a comma-separated list.
func CORS(allowedOrigins []string, next http.Handler) http.Handler {
	allowed := map[string]bool{}
	for _, o := range allowedOrigins {
		if o = strings.TrimSpace(o); o != "" {
			allowed[o] = true
		}
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if allowed[origin] {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Add("Vary", "Origin")
		}
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		w.Header().Set("Access-Control-Allow-Credentials", "true")

		if r.Method == http.MethodOptions { // preflight request
			w.WriteHeader(http.StatusNoContent)
			return // don't call the handler
		}
		next.ServeHTTP(w, r)
	})
}

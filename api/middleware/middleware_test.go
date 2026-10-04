package middleware

import (
	"database/sql"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"example.com/le-cinque/store"
)

func setupDB(t *testing.T) *sql.DB {
	t.Helper()
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		url = "postgres://localhost:5432/hellodb_test"
	}
	db, err := store.Open(url)
	if err != nil {
		t.Skipf("postgres unavailable: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	if _, err := db.Exec("TRUNCATE games, guesses, accounts, sessions, word_reviews"); err != nil {
		t.Fatal(err)
	}
	return db
}

func authRequest(db *sql.DB, cookie *http.Cookie) *httptest.ResponseRecorder {
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	req := httptest.NewRequest("GET", "/game", nil)
	if cookie != nil {
		req.AddCookie(cookie)
	}
	rec := httptest.NewRecorder()
	Auth(db, next).ServeHTTP(rec, req)
	return rec
}

func TestAuth_NoCookie(t *testing.T) {
	db := setupDB(t)

	rec := authRequest(db, nil)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}
}

func TestAuth_InvalidToken(t *testing.T) {
	db := setupDB(t)

	rec := authRequest(db, &http.Cookie{Name: "session", Value: "no-such-token"})

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}
}

func TestAuth_ExpiredSession(t *testing.T) {
	db := setupDB(t)
	if _, err := db.Exec("INSERT INTO sessions (token, username, expires_at) VALUES ($1, $2, $3)",
		"expired-token", "ann", time.Now().Add(-time.Hour)); err != nil {
		t.Fatal(err)
	}

	rec := authRequest(db, &http.Cookie{Name: "session", Value: "expired-token"})

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}
}

func TestAuth_ValidSession(t *testing.T) {
	db := setupDB(t)
	if _, err := db.Exec("INSERT INTO sessions (token, username, expires_at) VALUES ($1, $2, $3)",
		"valid-token", "ann", time.Now().Add(29*24*time.Hour)); err != nil {
		t.Fatal(err)
	}

	rec := authRequest(db, &http.Cookie{Name: "session", Value: "valid-token"})

	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rec.Code)
	}
}

func TestAuth_RefreshesExpiringSession(t *testing.T) {
	db := setupDB(t)
	if _, err := db.Exec("INSERT INTO sessions (token, username, expires_at) VALUES ($1, $2, $3)",
		"soon-token", "ann", time.Now().Add(time.Hour)); err != nil {
		t.Fatal(err)
	}

	rec := authRequest(db, &http.Cookie{Name: "session", Value: "soon-token"})

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	// the expiring session is extended and its cookie re-issued
	var found bool
	for _, c := range rec.Result().Cookies() {
		if c.Name == "session" && c.Value == "soon-token" {
			found = true
			if c.MaxAge != 30*86400 {
				t.Errorf("expected refreshed cookie MaxAge 2592000, got %d", c.MaxAge)
			}
		}
	}
	if !found {
		t.Error("expected a refreshed session cookie")
	}
	var expires time.Time
	if err := db.QueryRow("SELECT expires_at FROM sessions WHERE token = $1",
		"soon-token").Scan(&expires); err != nil {
		t.Fatal(err)
	}
	if left := time.Until(expires); left < 29*24*time.Hour || left > 31*24*time.Hour {
		t.Errorf("expected expiry pushed to ~30 days out, got %v", left)
	}
}

func TestAuth_KeepsFreshSession(t *testing.T) {
	db := setupDB(t)
	fresh := time.Now().Add(29 * 24 * time.Hour)
	if _, err := db.Exec("INSERT INTO sessions (token, username, expires_at) VALUES ($1, $2, $3)",
		"fresh-token", "ann", fresh); err != nil {
		t.Fatal(err)
	}

	rec := authRequest(db, &http.Cookie{Name: "session", Value: "fresh-token"})

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	// plenty of life left: no rewrite, so game traffic avoids an UPDATE per request
	for _, c := range rec.Result().Cookies() {
		if c.Name == "session" {
			t.Errorf("expected no refreshed cookie, got %v", c)
		}
	}
	var expires time.Time
	if err := db.QueryRow("SELECT expires_at FROM sessions WHERE token = $1",
		"fresh-token").Scan(&expires); err != nil {
		t.Fatal(err)
	}
	if expires.Sub(fresh) > time.Minute || fresh.Sub(expires) > time.Minute {
		t.Errorf("expected expiry untouched, got %v (was %v)", expires, fresh)
	}
}

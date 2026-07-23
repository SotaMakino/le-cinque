package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"sort"
	"strconv"
	"strings"

	"example.com/le-cinque/middleware"
)

const (
	WordsPerRound = 5
	// the fifth wrong placement ends the round as lost
	MaxMisses = 5
	// a lost round's words return once this many later rounds have been played
	ReviewGap = 3
)

type Games struct {
	DB *sql.DB
}

// game rows store the round's Italian words comma-joined in the word column,
// so the schema is the same as a single-word game.
type game struct {
	id     int64
	words  []string
	status string // playing | won | lost
	// "it" (default): the Italian word is the clue, the English word is spelled.
	// "en": flipped — the English word is the clue, the Italian word is spelled.
	direction string
}

type pair struct {
	Prompt string   `json:"prompt"` // the word shown in full as the clue
	Tiles  []string `json:"tiles"`  // one entry per letter of the answer: revealed letter or ""
}

type gameState struct {
	ID        int64    `json:"id"`
	Status    string   `json:"status"`    // "lost" = completed, flagged for review
	Direction string   `json:"direction"` // "it" | "en" — which word is spelled
	Pairs     []pair   `json:"pairs"`
	Guessed   []string `json:"guessed"`   // the letter of every placement tried, in order
	Results   []bool   `json:"results"`   // parallel to guessed: true = correct placement
	Wrong     []string `json:"wrong"`     // the letters of failed placements, in order
	UsedUp    []string `json:"usedUp"`    // letters whose every occurrence is revealed
	MaxMisses int      `json:"maxMisses"` // wrong placements allowed before losing
}

// answer is the word the player spells out on the tiles; clue is the word shown
// in full. The direction decides which side of the pair is which.
func (g *game) answer(w string) string {
	if g.direction == "en" {
		return w
	}
	return english[w]
}

func (g *game) clue(w string) string {
	if g.direction == "en" {
		return english[w]
	}
	return w
}

// normalizeDirection coerces client input to a known value, defaulting to "it".
func normalizeDirection(d string) string {
	if d == "en" {
		return "en"
	}
	return "it"
}

func (h *Games) latest(user string) (*game, error) {
	g := &game{}
	var joined string
	err := h.DB.QueryRow(
		"SELECT id, word, status, direction FROM games WHERE username = $1 ORDER BY id DESC LIMIT 1",
		user).Scan(&g.id, &joined, &g.status, &g.direction)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	g.words = strings.Split(joined, ",")
	return g, err
}

// history replays a user's finished rounds: every word of a round shares the
// round's outcome, and later rounds overwrite earlier ones.
type outcome struct {
	round int // 1-based index of the user's finished rounds
	won   bool
}

func (h *Games) history(user string) (map[string]outcome, int, error) {
	rows, err := h.DB.Query(
		"SELECT word, status FROM games WHERE username = $1 AND status <> 'playing' ORDER BY id",
		user)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	last := map[string]outcome{}
	round := 0
	for rows.Next() {
		var joined, status string
		if err := rows.Scan(&joined, &status); err != nil {
			return nil, 0, err
		}
		round++
		for _, w := range strings.Split(joined, ",") {
			last[w] = outcome{round, status == "won"}
		}
	}
	return last, round, rows.Err()
}

// nextWords picks a round's words. Priority:
//  1. spaced repetition — words lost at least ReviewGap finished rounds ago
//     and not won since (oldest miss first)
//  2. words the user has never played, in curriculum order — words.tsv is
//     ordered most-essential first, so beginners meet the core words soonest
//  3. not-yet-won words played longest ago (losses not due yet)
//  4. everything is won: recycle the words won longest ago
func (h *Games) nextWords(user string) ([]string, error) {
	last, round, err := h.history(user)
	if err != nil {
		return nil, err
	}

	picked := []string{}
	taken := map[string]bool{}
	take := func(w string) {
		if !taken[w] && len(picked) < WordsPerRound {
			taken[w] = true
			picked = append(picked, w)
		}
	}
	// repeatedly take the oldest-round word matching, until none match
	takeOldest := func(match func(outcome) bool) {
		for len(picked) < WordsPerRound {
			best, bestRound := "", round+1
			for _, v := range words {
				o, seen := last[v.Italian]
				if seen && !taken[v.Italian] && match(o) && o.round < bestRound {
					best, bestRound = v.Italian, o.round
				}
			}
			if best == "" {
				return
			}
			take(best)
		}
	}

	takeOldest(func(o outcome) bool { return !o.won && round-o.round >= ReviewGap })
	// unseen words, most-essential first (words.tsv order)
	for _, v := range words {
		if _, seen := last[v.Italian]; !seen {
			take(v.Italian)
		}
	}
	takeOldest(func(o outcome) bool { return !o.won })
	takeOldest(func(o outcome) bool { return true })
	return picked, nil
}

func (h *Games) create(user, direction string) (*game, error) {
	picked, err := h.nextWords(user)
	if err != nil {
		return nil, err
	}
	g := &game{words: picked, status: "playing", direction: direction}
	err = h.DB.QueryRow(
		"INSERT INTO games (username, word, status, direction) VALUES ($1, $2, 'playing', $3) RETURNING id",
		user, strings.Join(picked, ","), direction).Scan(&g.id)
	return g, err
}

// attempt is one letter placed on one tile, stored in guesses.guess as
// "L:word:pos" — e.g. "T:0:3" puts a T on the fourth tile of the first word.
type attempt struct {
	letter string
	word   int
	pos    int
}

func (a attempt) encode() string {
	return fmt.Sprintf("%s:%d:%d", a.letter, a.word, a.pos)
}

func decodeAttempt(s string) attempt {
	parts := strings.SplitN(s, ":", 3)
	if len(parts) != 3 {
		return attempt{word: -1, pos: -1}
	}
	w, _ := strconv.Atoi(parts[1])
	p, _ := strconv.Atoi(parts[2])
	return attempt{letter: parts[0], word: w, pos: p}
}

// correct reports whether the attempt's letter really sits on that tile.
func (g *game) correct(a attempt) bool {
	if a.word < 0 || a.word >= len(g.words) {
		return false
	}
	e := g.answer(g.words[a.word])
	return a.pos >= 0 && a.pos < len(e) && string(e[a.pos]) == a.letter
}

func (h *Games) attempts(g *game) ([]attempt, error) {
	rows, err := h.DB.Query("SELECT guess FROM guesses WHERE game_id = $1 ORDER BY id", g.id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	attempts := []attempt{}
	for rows.Next() {
		var s string
		if err := rows.Scan(&s); err != nil {
			return nil, err
		}
		attempts = append(attempts, decodeAttempt(s))
	}
	return attempts, rows.Err()
}

type tileKey struct{ word, pos int }

func revealedTiles(g *game, attempts []attempt) map[tileKey]bool {
	revealed := map[tileKey]bool{}
	for _, a := range attempts {
		if !g.correct(a) {
			continue
		}
		// a correct placement opens every occurrence of that letter, so the
		// player never has to place the same character twice
		for wi, w := range g.words {
			for i, r := range g.answer(w) {
				if string(r) == a.letter {
					revealed[tileKey{wi, i}] = true
				}
			}
		}
	}
	return revealed
}

func (h *Games) state(g *game) (gameState, error) {
	attempts, err := h.attempts(g)
	if err != nil {
		return gameState{}, err
	}
	s := gameState{
		ID:        g.id,
		Status:    g.status,
		Direction: g.direction,
		Pairs:     []pair{},
		Guessed:   []string{},
		Results:   []bool{},
		Wrong:     []string{},
		UsedUp:    []string{},
		MaxMisses: MaxMisses,
	}
	revealed := revealedTiles(g, attempts)
	for _, a := range attempts {
		s.Guessed = append(s.Guessed, a.letter)
		s.Results = append(s.Results, g.correct(a))
		if !g.correct(a) {
			s.Wrong = append(s.Wrong, a.letter)
		}
	}
	counts := map[string]int{} // occurrences of each letter in the round
	found := map[string]int{}  // revealed occurrences of each letter
	for wi, w := range g.words {
		e := g.answer(w)
		out := make([]string, len(e))
		for i, r := range e {
			counts[string(r)]++
			if revealed[tileKey{wi, i}] {
				found[string(r)]++
			}
			// a finished round shows everything
			if revealed[tileKey{wi, i}] || g.status != "playing" {
				out[i] = string(r)
			}
		}
		s.Pairs = append(s.Pairs, pair{Prompt: g.clue(w), Tiles: out})
	}
	for l, c := range counts {
		if found[l] == c {
			s.UsedUp = append(s.UsedUp, l)
		}
	}
	sort.Strings(s.UsedUp)
	return s, nil
}

func (h *Games) writeState(w http.ResponseWriter, code int, g *game) {
	s, err := h.state(g)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "query failed")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(s)
}

// Me returns the signed-in user's name and how many distinct words they have
// learned — a word counts as learned once it appears in any won round.
func (h *Games) Me(w http.ResponseWriter, r *http.Request) {
	user := middleware.Username(r)
	authed := middleware.Authenticated(r)
	var learned int
	err := h.DB.QueryRow(`SELECT COUNT(DISTINCT w) FROM (
		SELECT unnest(string_to_array(word, ',')) AS w
		FROM games WHERE username = $1 AND status = 'won'
	) t`, user).Scan(&learned)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "query failed")
		return
	}
	// the masthead's issue number is this player's own tally of rounds dealt,
	// counting up as they play (separate per account and per guest browser)
	var plays int
	if err := h.DB.QueryRow("SELECT COUNT(*) FROM games WHERE username = $1", user).Scan(&plays); err != nil {
		writeError(w, http.StatusInternalServerError, "query failed")
		return
	}
	// guest players play anonymously; only signed-in accounts show a name and
	// a persisted vocabulary count in the UI
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"username": user,
		"learned":  learned,
		"guest":    !authed,
		"plays":    plays,
	})
}

// Current returns the player's latest round, dealing a fresh one only when they
// have never played. Refreshing resumes an in-progress round with the same
// words rather than dealing a new one, so revisiting neither changes the board
// nor inflates the global play tally. A finished round stays visible (with its
// results) until the player starts a new one.
func (h *Games) Current(w http.ResponseWriter, r *http.Request) {
	user := middleware.Username(r)
	g, err := h.latest(user)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "query failed")
		return
	}
	if g == nil {
		if g, err = h.create(user, "it"); err != nil {
			writeError(w, http.StatusInternalServerError, "could not start a game")
			return
		}
	}
	h.writeState(w, http.StatusOK, g)
}

// New starts a fresh round once the current one is finished.
func (h *Games) New(w http.ResponseWriter, r *http.Request) {
	user := middleware.Username(r)
	g, err := h.latest(user)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "query failed")
		return
	}
	if g != nil && g.status == "playing" {
		writeError(w, http.StatusConflict, "finish the current game first")
		return
	}
	// carry the player's chosen direction into the next round
	dir := "it"
	if g != nil {
		dir = g.direction
	}
	g, err = h.create(user, dir)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not start a game")
		return
	}
	h.writeState(w, http.StatusCreated, g)
}

// Reset wipes the in-progress round's guesses so it starts over with the
// same five words.
func (h *Games) Reset(w http.ResponseWriter, r *http.Request) {
	user := middleware.Username(r)
	g, err := h.latest(user)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "query failed")
		return
	}
	if g == nil || g.status != "playing" {
		writeError(w, http.StatusConflict, "no game in progress")
		return
	}
	if _, err := h.DB.Exec("DELETE FROM guesses WHERE game_id = $1", g.id); err != nil {
		writeError(w, http.StatusInternalServerError, "could not reset the game")
		return
	}
	h.writeState(w, http.StatusOK, g)
}

// Retry restarts the just-finished round with the same five words.
func (h *Games) Retry(w http.ResponseWriter, r *http.Request) {
	user := middleware.Username(r)
	g, err := h.latest(user)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "query failed")
		return
	}
	if g == nil || g.status == "playing" {
		writeError(w, http.StatusConflict, "no finished game to retry")
		return
	}
	fresh := &game{words: g.words, status: "playing", direction: g.direction}
	if err := h.DB.QueryRow(
		"INSERT INTO games (username, word, status, direction) VALUES ($1, $2, 'playing', $3) RETURNING id",
		user, strings.Join(g.words, ","), g.direction).Scan(&fresh.id); err != nil {
		writeError(w, http.StatusInternalServerError, "could not start a game")
		return
	}
	h.writeState(w, http.StatusCreated, fresh)
}

// SetDirection flips the current round between guessing the English word and
// guessing the Italian one. It is allowed only before the player has placed any
// letter — the UI disables the language flags once a round is underway. Changing
// direction also deals a fresh set of words, reusing the untouched round's row so
// the play tally is not inflated.
func (h *Games) SetDirection(w http.ResponseWriter, r *http.Request) {
	user := middleware.Username(r)
	var body struct {
		Direction string `json:"direction"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	dir := normalizeDirection(body.Direction)

	g, err := h.latest(user)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "query failed")
		return
	}
	if g == nil || g.status != "playing" {
		writeError(w, http.StatusConflict, "no game in progress")
		return
	}
	attempts, err := h.attempts(g)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "query failed")
		return
	}
	if len(attempts) > 0 {
		writeError(w, http.StatusConflict, "round already started")
		return
	}
	if g.direction != dir {
		picked, err := h.nextWords(user)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "query failed")
			return
		}
		if _, err := h.DB.Exec(
			"UPDATE games SET word = $1, direction = $2 WHERE id = $3",
			strings.Join(picked, ","), dir, g.id); err != nil {
			writeError(w, http.StatusInternalServerError, "could not switch direction")
			return
		}
		g.words = picked
		g.direction = dir
	}
	h.writeState(w, http.StatusOK, g)
}

// Guess places one letter on one tile of the current round.
func (h *Games) Guess(w http.ResponseWriter, r *http.Request) {
	user := middleware.Username(r)
	var body struct {
		Guess    string `json:"guess"`
		Word     int    `json:"word"`     // 0-based pair index
		Position int    `json:"position"` // 0-based tile index within the word
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	letter := strings.ToUpper(strings.TrimSpace(body.Guess))
	if len(letter) != 1 || letter[0] < 'A' || letter[0] > 'Z' {
		writeError(w, http.StatusBadRequest, "guess one letter (A-Z)")
		return
	}

	g, err := h.latest(user)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "query failed")
		return
	}
	if g == nil || g.status != "playing" {
		writeError(w, http.StatusConflict, "no game in progress")
		return
	}
	if body.Word < 0 || body.Word >= len(g.words) ||
		body.Position < 0 || body.Position >= len(g.answer(g.words[body.Word])) {
		writeError(w, http.StatusBadRequest, "no such tile")
		return
	}
	a := attempt{letter: letter, word: body.Word, pos: body.Position}

	attempts, err := h.attempts(g)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "query failed")
		return
	}
	revealed := revealedTiles(g, attempts)
	if revealed[tileKey{a.word, a.pos}] {
		writeError(w, http.StatusBadRequest, "tile already revealed")
		return
	}
	wrong := 0
	for _, prev := range attempts {
		if !g.correct(prev) {
			wrong++
		}
		if prev == a {
			writeError(w, http.StatusBadRequest, "already tried that letter there")
			return
		}
	}

	if _, err := h.DB.Exec(
		"INSERT INTO guesses (game_id, guess) VALUES ($1, $2)", g.id, a.encode()); err != nil {
		writeError(w, http.StatusInternalServerError, "could not save guess")
		return
	}

	if g.correct(a) {
		revealed = revealedTiles(g, append(attempts, a))
	} else {
		wrong++
	}
	total := 0
	for _, w := range g.words {
		total += len(g.answer(w))
	}
	switch {
	case wrong >= MaxMisses:
		g.status = "lost" // the fifth miss ends the round
	case len(revealed) == total:
		g.status = "won"
	}
	if g.status != "playing" {
		if _, err := h.DB.Exec("UPDATE games SET status = $1 WHERE id = $2", g.status, g.id); err != nil {
			writeError(w, http.StatusInternalServerError, "could not update game")
			return
		}
	}
	h.writeState(w, http.StatusOK, g)
}

func writeError(w http.ResponseWriter, code int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

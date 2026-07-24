package handlers

import (
	_ "embed"
	"strings"
)

// vocab is one curriculum entry: an essential Italian word and the English
// word with the same meaning. Both uppercase A–Z; lengths vary freely. Theme is
// the "#" heading the entry sits under, used to keep a round off a single
// semantic set (see nextWords).
type vocab struct {
	Italian string
	English string
	Theme   string
}

// wordsTSV is the curriculum, kept as data rather than Go literals: one
// "ITALIAN<tab>ENGLISH" pair per line, grouped by "#" theme comments. It holds
// 1500+ essential beginner words. Accented words (caffè, città, lunedì, …) are
// excluded so the game stays on plain A–Z.
//
//go:embed words.tsv
var wordsTSV string

// words is the parsed curriculum, in words.tsv order — most-essential first.
// Rounds draw five, review words first, then unseen words in this order
// (see nextWords).
var words = parseVocab(wordsTSV)

// parseVocab reads the embedded TSV, skipping blank lines. A "#" comment is not
// discarded but kept as the theme of every entry below it, until the next one.
func parseVocab(data string) []vocab {
	lines := strings.Split(data, "\n")
	out := make([]vocab, 0, len(lines))
	theme := ""
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, "#") {
			// "# --- food & drink ---" is the theme "food & drink"
			theme = strings.Trim(strings.TrimPrefix(line, "#"), " -")
			continue
		}
		it, en, ok := strings.Cut(line, "\t")
		if !ok {
			continue
		}
		out = append(out, vocab{
			Italian: strings.TrimSpace(it),
			English: strings.TrimSpace(en),
			Theme:   theme,
		})
	}
	return out
}

// english maps an Italian curriculum word to its translation.
var english = func() map[string]string {
	m := make(map[string]string, len(words))
	for _, v := range words {
		m[v.Italian] = v.English
	}
	return m
}()

// ambiguousEnglish holds the English words that translate more than one entry —
// PUSH is both SPINGERE and SPINTA. They work as answers (the Italian word is
// the clue) but not as prompts in the "en" direction, where the player would see
// PUSH with no way to tell which spelling the tiles want, so nextWords skips
// them there.
var ambiguousEnglish = func() map[string]bool {
	count := make(map[string]int, len(words))
	for _, v := range words {
		count[v.English]++
	}
	m := map[string]bool{}
	for en, n := range count {
		if n > 1 {
			m[en] = true
		}
	}
	return m
}()

# The site builds nothing here; GitHub Pages builds docs/ with Jekyll.
# check: the vendored scanner matches its pinned sum, every hygiene group reads
# 0 files outside .hygiene-allow, and no page holds an em-dash. It needs git,
# shasum and /usr/bin/python3.
#
# scripts/hygiene-gate runs the vendored scanner, scripts/hygiene, over the tree
# and judges every group. The scanner's own groups name nobody. A maintainer's
# private list, read from outside the repository ($AGENTIK_HYGIENE_PRIVATE, else
# ${XDG_CONFIG_HOME:-$HOME/.config}/agentik/hygiene-private.tsv), adds the words
# that must never be published; without one the scan runs on its own groups.
# HYGIENE_OWN names the product's own words, which such a list may hold for
# other repositories and this one, the product's public face, uses.
HYGIENE_OWN := syrvis synology
.PHONY: check hygiene emdash
check: hygiene emdash
hygiene:
	@shasum -a 256 -c --status scripts/vendored.sha256 || { echo 'check: scripts/hygiene no longer matches its sum in scripts/vendored.sha256'; exit 2; }
	@/usr/bin/python3 -I scripts/hygiene-gate $(HYGIENE_OWN)
emdash:
	@! grep -rl "$$(printf '\342\200\224')" --include='*.md' --include='*.yml' . || { echo 'check: an em-dash in the files above'; exit 1; }

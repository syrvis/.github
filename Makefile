# The site builds nothing here; GitHub Pages builds docs/ with Jekyll.
# check: the vendored scan matches its pinned sum, the hygiene scan finds no hit
# outside .hygiene-allow, and no page holds an em-dash.
# The owner's private list names the product and its platform, since every other
# repo must not; this repo is the product's public face, so the scan reads that
# list without those two lines and with the organisation's private repos named
# in their place.
PRIVATE := $(or $(AGENTIK_HYGIENE_PRIVATE),$(or $(XDG_CONFIG_HOME),$(HOME)/.config)/agentik/hygiene-private.tsv)
.PHONY: check
check:
	shasum -a 256 -c --status scripts/vendored.sha256
	@t=$$(mktemp); trap 'rm -f "$$t"' EXIT; \
	{ [ -f "$(PRIVATE)" ] && grep -vxE 'private	\\bsyrvis|device	synology' "$(PRIVATE)"; \
	  printf 'private\tsyrvis-(hq|corpus|konsume)\n'; } > "$$t"; \
	AGENTIK_HYGIENE_PRIVATE="$$t" scripts/hygiene
	@! grep -rl "$$(printf '\342\200\224')" --include='*.md' --include='*.yml' . || { echo 'check: an em-dash in the files above'; exit 1; }

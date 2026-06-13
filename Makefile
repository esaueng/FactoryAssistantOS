# Factory Assistant OS — thin entry points around scripts/.
# See docs/OS_BUILD.md for prerequisites and the full build guide.

.PHONY: help bootstrap overlay os check clean distclean

help:
	@echo "Factory Assistant OS build entry points:"
	@echo "  make bootstrap   - clone pinned upstream Home Assistant OS into upstream/"
	@echo "  make overlay     - apply the Factory Assistant rebrand/config overlay"
	@echo "  make os          - build the image (TARGET=generic_x86_64 by default)"
	@echo "  make check       - syntax-check the shell scripts"
	@echo "  make clean       - remove build output, keep upstream sources"
	@echo "  make distclean   - remove the entire upstream/ checkout"

bootstrap:
	./scripts/bootstrap.sh

overlay:
	./scripts/apply-overlay.sh

os:
	./scripts/build.sh

check:
	bash -n scripts/*.sh
	@command -v shellcheck >/dev/null 2>&1 && shellcheck scripts/*.sh || echo "shellcheck not installed - skipped"

clean:
	rm -rf upstream/operating-system/output

distclean:
	rm -rf upstream

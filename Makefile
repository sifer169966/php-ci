ROOT_PROJ := $(CURDIR)
target ?=

# require php version 7.1 (latest patch recommended is 7.1.33)
init:
	@echo "== 👩‍🌾 ci init =="
	brew install php@7.1
	brew install node
	brew install pre-commit

	@echo "== pre-commit setup =="
	pre-commit install

	@echo "== install dependencies from composer.json =="
	./composer.phar install

	@echo "== install hook =="
	$(MAKE) precommit.rehooks

# installs the pre-commit hooks defined in the .pre-commit-config.yaml, specifically installs the commit-msg hook. \
The commit-msg hook is a special type of pre-commit hook that runs after you write your commit message \
but before the commit is finalized.
precommit.rehooks:
	pre-commit autoupdate
	pre-commit install --install-hooks
	pre-commit install --hook-type commit-msg

# Checking entire project If there are any syntax errors \
to check specific files \
``` \
make ci.syntax target=path/to/phpfile1 \
``` \
for multiple files specifically \
``` \
make ci.syntax target="path/to/phpfile1 path/to/phpfile2" \
```
ci.syntax:
	./syntax_check.sh -s all --exclude vendor/ $(target)

# Validate the coding style following the configuration file from /vendor/squizlabs/.phpcs.xml. \
This command also supported the arguments, see below \
1. fix, If set to `true` it gonna use `phpcbf` command to fix the target file to follow the rules set from the configuration file, \
otherwise use `phpcs` command and throw the result as a stdout \
2. target, If this parameter has bees passed as an argument, the `linter` only apply on that `target`, \
otherwise checking entire project that have `.php` extension \
3. opts, support all of the options that `phpcs` or `phpcbf` supports, you can passing mutiple options by separating with the comma(,) \
Example of usage with no opts \
```\
make ci.lint fix=true target=/path/to/your/target \
```\
Example of usage with opts \
```\
make ci.lint fix=true opts=--opt1=hello1,--opt2=hello2 target=/path/to/your/target \
```\
more detail about option from `./vendor/bin/phpcbf --help` and `vendor/bin/phpcs --help` \
NOTE: you can use this command if the pre-commit hook throw you any error about invaliad coding style by set `fix=true`
ci.lint:
	@if [ "$(fix)" = "true" ]; then \
		LINTER_COMMAND="$(ROOT_PROJ)/vendor/bin/phpcbf"; \
	else \
		LINTER_COMMAND="$(ROOT_PROJ)/vendor/bin/phpcs"; \
	fi; \
	\
	if [ -n "$(opts)" ]; then \
		OPTIONS="$$(echo "$(opts)" | tr ',' ' ')"; \
	else \
		OPTIONS=""; \
	fi; \
	\
	OPTIONS+=" --ignore=vendor/"; \
	$$LINTER_COMMAND $$OPTIONS --standard=$(ROOT_PROJ)/.phpcs.xml $(ROOT_PROJ)/$(target); \
	exit 0


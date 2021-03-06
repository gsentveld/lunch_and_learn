.PHONY: clean 

#################################################################################
# GLOBALS                                                                       #
#################################################################################

PROJECT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
PROJECT_NAME = lunch_and_learn
PYTHON_INTERPRETER = python3

ifeq (,$(shell which conda))
HAS_CONDA=False
else
HAS_CONDA=True
endif

BASE_URL=https://ftp.cdc.gov/pub/Health_Statistics/NCHS/Datasets/NHIS/2015/


EXTERNAL_DATA_DIR=$(PROJECT_DIR)/data/external
RAW_DATA_DIR=$(PROJECT_DIR)/data/raw
INTERIM_DATA_DIR=$(PROJECT_DIR)/data/interim
PROCESSED_DATA_DIR=$(PROJECT_DIR)/data/processed


ZIP_FILES=cancerxx.zip familyxx.zip fmlydisb.zip funcdisb.zip househld.zip injpoiep.zip paradata.zip personsx.zip samadult.zip samchild.zip

SAVED_ZIP_FILES=$(addprefix $(EXTERNAL_DATA_DIR)/, $(ZIP_FILES))

CSV_FILES=$(RAW_DATA_DIR)/cancerxx.csv \
	$(RAW_DATA_DIR)/familyxx.csv \
	$(RAW_DATA_DIR)/fmlydisb.csv \
	$(RAW_DATA_DIR)/funcdisb.csv \
	$(RAW_DATA_DIR)/househld.csv \
	$(RAW_DATA_DIR)/injpoiep.csv \
	$(RAW_DATA_DIR)/paradata.csv \
	$(RAW_DATA_DIR)/personsx.csv \
	$(RAW_DATA_DIR)/samadult.csv \
	$(RAW_DATA_DIR)/samchild.csv


#################################################################################
# COMMANDS                                                                      #
#################################################################################

## Install Python Dependencies
requirements: test_environment requirements.txt
	pip install -r requirements.txt
	touch requirements

## Make all the slides for all the pieces.
slides:  $(wildcard notebooks/*.ipynb)
	jupyter nbconvert --to slides $?

## Get the zipfiles from the CDC website
$(SAVED_ZIP_FILES): notebooks/Get_zip_files.ipynb
	mkdir -p $(EXTERNAL_DATA_DIR)
	jupyter nbconvert --ExecutePreprocessor.timeout=600 --ExecutePreprocessor.kernel_name=python3 --to slides --execute notebooks/Get_zip_files.ipynb

## Get the CSV files extracted from the zipfiles 
$(CSV_FILES): $(SAVED_ZIP_FILES) notebooks/Unzip_Files_Keep_CSV_Files.ipynb
	mkdir -p $(RAW_DATA_DIR)
	jupyter nbconvert --ExecutePreprocessor.timeout=600 --ExecutePreprocessor.kernel_name=python3 --to slides --execute notebooks/Unzip_Files_Keep_CSV_Files.ipynb

## Make Dataset
data: requirements $(CSV_FILES) 
	mkdir -p $(INTERIM_DATA_DIR) $(PROCESSED_DATA_DIR)
	$(PYTHON_INTERPRETER) src/data/make_dataset.py $(INTERIM_DATA_DIR) $(PROCESSED_DATA_DIR)

## Delete all compiled Python files
clean:
	find . -name "*.pyc" -exec rm {} \;
	rm requirements test_environment


## Set up python interpreter environment
create_environment:
ifeq (True,$(HAS_CONDA))
		@echo ">>> Detected conda, creating conda environment."
ifeq (3,$(findstring 3,$(PYTHON_INTERPRETER)))
	conda create --name $(PROJECT_NAME) python=3.5
else
	conda create --name $(PROJECT_NAME) python=2.7
endif
		@echo ">>> New conda env created. Activate with:\nsource activate $(PROJECT_NAME)"
else
	@pip install -q virtualenv virtualenvwrapper
	@echo ">>> Installing virtualenvwrapper if not already intalled.\nMake sure the following lines are in shell startup file\n\
	export WORKON_HOME=$$HOME/.virtualenvs\nexport PROJECT_HOME=$$HOME/Devel\nsource /usr/local/bin/virtualenvwrapper.sh\n"
	@bash -c "source `which virtualenvwrapper.sh`;mkvirtualenv $(PROJECT_NAME) --python=$(PYTHON_INTERPRETER)"
	@echo ">>> New virtualenv created. Activate with:\nworkon $(PROJECT_NAME)"
endif

## Test python environment is setup correctly
test_environment: test_environment.py
	$(PYTHON_INTERPRETER) test_environment.py
	touch test_environment

#################################################################################
# PROJECT RULES                                                                 #
#################################################################################



#################################################################################
# Self Documenting Commands                                                     #
#################################################################################

.DEFAULT_GOAL := show-help

# Inspired by <http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html>
# sed script explained:
# /^##/:
# 	* save line in hold space
# 	* purge line
# 	* Loop:
# 		* append newline + line to hold space
# 		* go to next line
# 		* if line starts with doc comment, strip comment character off and loop
# 	* remove target prerequisites
# 	* append hold space (+ newline) to line
# 	* replace newline plus comments by `---`
# 	* print line
# Separate expressions are necessary because labels cannot be delimited by
# semicolon; see <http://stackoverflow.com/a/11799865/1968>
.PHONY: show-help
show-help:
	@echo "$$(tput bold)Available rules:$$(tput sgr0)"
	@echo
	@sed -n -e "/^## / { \
		h; \
		s/.*//; \
		:doc" \
		-e "H; \
		n; \
		s/^## //; \
		t doc" \
		-e "s/:.*//; \
		G; \
		s/\\n## /---/; \
		s/\\n/ /g; \
		p; \
	}" ${MAKEFILE_LIST} \
	| LC_ALL='C' sort --ignore-case \
	| awk -F '---' \
		-v ncol=$$(tput cols) \
		-v indent=19 \
		-v col_on="$$(tput setaf 6)" \
		-v col_off="$$(tput sgr0)" \
	'{ \
		printf "%s%*s%s ", col_on, -indent, $$1, col_off; \
		n = split($$2, words, " "); \
		line_length = ncol - indent; \
		for (i = 1; i <= n; i++) { \
			line_length -= length(words[i]) + 1; \
			if (line_length <= 0) { \
				line_length = ncol - indent - length(words[i]) - 1; \
				printf "\n%*s ", -indent, " "; \
			} \
			printf "%s ", words[i]; \
		} \
		printf "\n"; \
	}' \
	| more $(shell test $(shell uname) = Darwin && echo '--no-init --raw-control-chars')

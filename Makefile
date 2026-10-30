# One-command local workflow. `make all` = what the monthly GitHub Action does.
MONTHS ?= 12
DBT = cd dbt_project && dbt

.PHONY: all install ingest build test analysis bench forecast dashboard dev clean

all: ingest build forecast dashboard

install:
	pip install -r requirements.txt
	cd dashboard && npm ci

ingest:            ## download new months + weather into data/raw
	python -m ingestion.run --latest $(MONTHS)

build:             ## dbt models + tests
	mkdir -p data/warehouse
	$(DBT) build --profiles-dir .

test:
	python -m unittest discover -s ingestion/tests -t .
	$(DBT) test --profiles-dir .

analysis:          ## run the showcase SQL in analysis/
	$(DBT) compile --profiles-dir . --select "resource_type:analysis"
	python analysis/run.py

bench:             ## EXPLAIN ANALYZE before/after -> analysis/06_explain_analyze_results.md
	python analysis/06_explain_analyze.py

forecast:
	python forecasting/train.py

dashboard:
	cd dashboard && npm run sources && npm run build

dev:
	cd dashboard && npm run sources && npm run dev

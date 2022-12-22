build:
	@echo "NOTE: Python3 with pip3 is required!"
	@echo "Installing requirements..."
	pip3 install -r requirements.txt
	@echo "DONE!"

test:
	@echo "NOTE: AWS credentials are required in your env!"
	./test.sh

env:
	env

all: build test

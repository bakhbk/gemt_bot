.PHONY: build run build-run clean logs shell

# Build the Docker image
build:
	@echo "Building Docker image..."
	docker build -t gemt_bot .

# Run the container
run:
	@echo "Starting container..."
	docker run gemt_bot

# Build and run in one command
build-run: build run

# Clean up containers and images
clean:
	@echo "Cleaning up..."
	@docker stop $$(docker ps -aq --filter ancestor=gemt_bot) 2>/dev/null || true
	@docker rm $$(docker ps -aq --filter ancestor=gemt_bot) 2>/dev/null || true
	@docker rmi gemt_bot 2>/dev/null || true

# View logs
logs:
	@docker logs -f $$(docker ps -q --filter ancestor=gemt_bot)

# SSH into running container
shell:
	@docker exec -it $$(docker ps -q --filter ancestor=gemt_bot) /bin/bash
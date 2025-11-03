# Make file for building the image, cleaning, pushing and running locally and remote.

# If the image does not exits, it will build it first, then run it.
# If the image exists but is not started it will create a new container.
# If the container is stopped then it will start it again.
# if the container is running it will attach a new shell to it.
start:
	@bash -c ' \
	source ./makefile.sh; \
	start  \
	echo "Done"; '

# Target for building the image
build-nocache: 
	@bash -c ' \
	source ./makefile.sh; \
	buildNoCache; \
	echo "Done"; '

# Target for building the image
build: 
	@bash -c ' \
	source ./makefile.sh; \
	build; \
	echo "Done"; '

buildx:
	@bash -c ' \
	source ./makefile.sh; \
	buildx; \
	echo "Done"; '
	
integration:
	@bash -c ' \
	source ./makefile.sh; \
	integration  \
	echo "Done"; '
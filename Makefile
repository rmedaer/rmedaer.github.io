mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir := $(dir $(mkfile_path))

all:
	docker run --name raphael.medaer.me --rm -v=${mkfile_dir}:/mnt -p 4000:4000 -w /mnt -it jekyll/jekyll jekyll serve --force_polling --watch

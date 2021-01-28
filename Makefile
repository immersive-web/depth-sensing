LOCAL_BIKESHED := $(shell command -v bikeshed 2> /dev/null)

.PHONY: all index.html

all: index.html directories images

directories:
	mkdir -p out/img

images: img/depth_api_data_explained.png
	cp img/depth_api_data_explained.png out/img/depth_api_data_explained.png

index.html: index.bs
ifndef LOCAL_BIKESHED
	curl https://api.csswg.org/bikeshed/ -F file=@index.bs -F output=err
	curl https://api.csswg.org/bikeshed/ -F file=@index.bs -F force=1 > out/index.html | tee
else
	bikeshed spec index.bs out/index.html
endif

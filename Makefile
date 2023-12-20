
antipopd:
	clang -framework AppKit -framework IOKit -framework AVFoundation -o antipopd antipopd.m

clean:
	rm -f antipopd

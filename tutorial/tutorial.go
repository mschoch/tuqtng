package main

import (
	"io/ioutil"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"time"

	"github.com/couchbaselabs/clog"
	"github.com/russross/blackfriday"
)

func setup(cacheDir string, src string, srcF os.FileInfo, err error) error {
	if strings.HasPrefix(srcF.Name(), ".") {
		return nil
	}

	dst := cacheDir + src
	if strings.HasSuffix(dst, ".md") {
		dst = strings.TrimSuffix(dst, ".md") + ".html"
	}
	dstF, dstE := os.Stat(dst)

	// if up to date, skip
	if !os.IsNotExist(dstE) &&
		(srcF.IsDir() || dstF.ModTime().After(srcF.ModTime())) {
		return nil
	}

	// copy to cache
	if os.IsNotExist(dstE) {
		clog.Log("Copying %s", srcF.Name())
	} else {
		clog.Log("Updating %s", srcF.Name())
	}

	if srcF.IsDir() {
		if err := os.MkdirAll(dst, srcF.Mode()); err != nil {
			return err
		}
		return nil
	}

	sbuf, err := ioutil.ReadFile(src)
	if err != nil {
		return err
	}
	dbuf := sbuf
	if strings.HasSuffix(src, ".md") {
		dbuf = blackfriday.MarkdownCommon(sbuf)
	}
	if err := ioutil.WriteFile(dst, dbuf, srcF.Mode()); err != nil {
		return err
	}

	return nil
}

func main() {
	tempDir, _ := ioutil.TempDir("", "tut")
	tempDir += string(os.PathSeparator)
	defer os.RemoveAll(tempDir)
	clog.Log("Workdir %s", tempDir)

	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	go func() {
		<-c
		os.RemoveAll(tempDir)
		clog.Fatal("Stopped")
	}()

	walker := func(src string, f os.FileInfo, err error) error {
		return setup(tempDir, src, f, err)
	}

	if err := filepath.Walk("./content/", walker); err != nil {
		clog.Fatalf("Filewalk %v", err)
	}

	clog.Log("Running at http:///localhost:8000/")

	go func() {
		for {
			filepath.Walk("./content/", walker)
			time.Sleep(2 * time.Second)
		}
	}()

	http.Handle("/", http.RedirectHandler("/tutorial/tutorial.html#1", 302))

	url, _ := url.Parse("http://localhost:8093")
	rp := httputil.NewSingleHostReverseProxy(url)
	http.Handle("/query", rp)

	fs := http.FileServer(http.Dir(tempDir + "/content/"))
	http.Handle("/tutorial/", http.StripPrefix("/tutorial/", fs))

	if err := http.ListenAndServe(":8000", nil); err != nil {
		clog.Fatalf("ListenAndServe %v", err)
	}
}

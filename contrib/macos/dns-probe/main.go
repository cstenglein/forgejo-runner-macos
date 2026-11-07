// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"fmt"
	"net"
	"net/http"
	"net/url"
	"os"
	"time"
)

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: dns-probe https://instance.example/api/v1/version")
		os.Exit(2)
	}
	u, err := url.Parse(os.Args[1])
	if err != nil || u.Scheme != "https" || u.Host == "" || u.User != nil {
		fmt.Fprintln(os.Stderr, "an HTTPS URL without credentials is required")
		os.Exit(2)
	}
	client := &http.Client{
		Timeout: 15 * time.Second,
		Transport: &http.Transport{
			Proxy: http.ProxyFromEnvironment,
			DialContext: (&net.Dialer{
				Timeout: 10 * time.Second,
			}).DialContext,
		},
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if req.URL.Scheme != "https" || req.URL.User != nil || len(via) >= 10 {
				return fmt.Errorf("redirect rejected")
			}
			return nil
		},
	}
	response, err := client.Get(u.String())
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		fmt.Fprintln(os.Stderr, response.Status)
		os.Exit(1)
	}
	fmt.Printf("Native Go DNS and verified HTTPS succeeded: %s\n", response.Status)
}

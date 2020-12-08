SHELL := /bin/bash
PWD := $(shell pwd)

install:
	cp -i 80-autorip.rules /etc/udev/rules.d/
	cp -i handbraker.sh /usr/local/bin/
	cp -i dvdrip@.service /etc/systemd/system/
	source config.env; sed -i \
		-e "s#^ExecStart=#ExecStart=$(PWD)/autorip.sh %i#" \
		-e "s#^User=#User=$$SUDO_USER#" \
		-e "s#^WorkingDirectory=#WorkingDirectory=${MKV_DEST}#" \
		/etc/systemd/system/dvdrip@.service
	chown root:root /usr/local/bin/handbraker.sh
	chmod 0700 /usr/local/bin/handbraker.sh
	sha256sum /usr/local/bin/handbraker.sh
	/bin/systemctl daemon-reload

uninstall:
	rm -i \
		/usr/local/bin/handbraker.sh \
		/etc/systemd/system/dvdrip@.service \
		/etc/udev/rules.d/80-autorip.rules

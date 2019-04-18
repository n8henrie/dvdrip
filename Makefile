SHELL := /bin/bash
PWD := $(shell pwd)

install:
	cp -i 80-autorip.rules /etc/udev/rules.d/
	cp -i handbraker.sh /usr/local/bin/
	cp -i autorip.service /etc/systemd/system/
	sed -i \
		-e "s#ExecStart=#ExecStart=$(PWD)/autorip.sh#" \
		-e "s#User=#User=$$SUDO_USER#" \
		/etc/systemd/system/autorip.service
	chown root:root /usr/local/bin/handbraker.sh
	chmod 0700 /usr/local/bin/handbraker.sh
	sha256sum /usr/local/bin/handbraker.sh
	/bin/systemctl daemon-reload

uninstall:
	rm -i \
		/usr/local/bin/handbraker.sh \
		/etc/systemd/system/autorip.service \
		/etc/udev/rules.d/80-autorip.rules

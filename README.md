## About

This script has been ported to Ubuntu 12.04. It will: 

 1. download the Debian 6.0 64bit iso via torrent
 2. ... do some magic to turn it into a vagrant box file
 3. output package.box

## Usage

    $ ./build.sh

This should do everything you need. You will need sudo permissions at one point
and have the following packages installed, if they aren't already:

* vagrant
* virtualbox-guest-additions-iso
* virtualbox
* transmission-cli
* mkisofs
* file-roller

If any of those are missing, add them (the script will guide you, too):
`sudo aptitude install [package1] [package2] [...]`.

### Localization

The default image built will have en_US language, but Swiss German keyboard and
UTC as time zone. To change this to your locale, edit the file `preseed.cfg`
before running the script. You could also add some packages to preinstall.
Interesting options might be:

* debian-installer/country (country, ex. `US`)
* console-keymaps-at/keymap (keymap, ex. `us`)
* keyboard-configuration/xkb-keymap (keymap, ex. `us`)
* time/zone (time zone, ex. `Europe/Zurich`)
* pkgsel/include (packages to include, ex. `cowsay fortune-mod sl`)

### Simon's notes

Changed the script to output a Debian Squeeze box instead. Also changed it, to
be more portable (runs with dash now, instead of bash) and to only use sudo
where not otherwise possible. Changed the preseed to default to Switzerland.
Chef is now installed from the official opscode repos as packages, which should
make them easier to maintain. The script now cleans up at the end. It does not
delete the custom iso, in case you want to use it for other unattended installs.

### Kev's notes

"Let's do it all on my **Ubuntu PC**, I said."

Standing on the shoulder's of giants (thanks Carl & Ben) - I have 
modified this `bash` script to work on Ubuntu 12.04 (Precise Pangolin). 
I also modified to download via torrent instead of slow HTTP.

### Ben's notes

Forked Carl's repo, and it sort of worked out of the box. Tweaked 
office 12.04 release: 

 - Downloading 12.04 final release. (Today as of this writing)
 - Checking MD5 to make sure it is the right version
 - Added a few more checks for external dependencies, mkisofs
 - Removed wget, and used curl to reduce dependencies
 - Added more output to see what is going on
 - Still designed to work on Mac OS X :)
    ... though it should work for Linux systems too (maybe w/ a bit of porting)

### Carl's original README

Decided I wanted to learn how to make a vagrant base box.

Let's target Precise Pangolin since it should be releasing soon, I said.

Let's automate everything, I said.

Let's do it all on my macbook, I said.

Woo.

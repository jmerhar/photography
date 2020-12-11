# Photography Scripts

## remove-sidecars.pl

I like to shoot with my camera in RAW+JPEG mode, in order to have high-quality raw photos, but also jpegs
for quick preview and to quickly send to my phone for example. Lightroom is smart enough to recognise
these jpegs as sidecars for the main raw photos, which means that they don't bother me much.

All is good then, but when my catalogue reached 100k+ photos, I realised that these sidecars were taking up
a lot of space on my hard drive, for no added benefit. When I tried to delete them I realised that Lightroom
had no feature to do that. So I decided to write a script for it. I ended up freeing 300+ GB of disk space.

### Usage

Download the script and make it executable. Run it with the path to your photos. You'll be prompted to provide
a list of extensions for your sidecars and for your raw photos. Press enter to accept the defaults or provide a
space-separated list of extensions. The script will then scan your photos, give a summary of the files it found,
and ask you to confirm that you want to delete them. At the end you'll get a summary with the total disk space
recovered.

```
# After downloading, make the script executable
$ chmod a+x remove-sidecars.pl

# Run it with the path to your photos
$ ./remove-sidecars.pl /path/to/my/photos
What extensions do your sidecars have? [JPG jpg JPEG jpeg] JPG jpg
What extensions do your raw photos have? [RW2 CR2 DNG dng] RW2 DNG
Scanning directory /path/to/my/photos
Scanning directory /path/to/my/photos/1
Scanning directory /path/to/my/photos/2

Found sidecars of:
- 2 RW2 files
- 3 DNG files

Would you like to delete them? [y/N] y
Deleting /path/to/my/photos/1/IMG_174456.jpg (4.76 MB), a sidecar of RW2
Deleting /path/to/my/photos/1/IMG_171458.jpg (4.35 MB), a sidecar of RW2
Deleting /path/to/my/photos/2/IMG_175816.jpg (3.75 MB), a sidecar of DNG
Deleting /path/to/my/photos/2/IMG_165528.jpg (5.18 MB), a sidecar of DNG
Deleting /path/to/my/photos/2/IMG_171956.jpg (4.33 MB), a sidecar of DNG

In total 22.37 MB of disk space was recovered:
- 9.11 MB of disk space was recovered from 2 RW2 sidecars (on average 4.56 MB per file).
- 13.26 MB of disk space was recovered from 3 DNG sidecars (on average 4.42 MB per file).
```

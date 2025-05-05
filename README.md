# Photography Scripts

A collection of utilities for managing photography workflows. Currently includes:

1. **remove-sidecars.pl** - Clean up unnecessary sidecar files
2. **photo-backup.sh** - Intelligent merged backup solution for photo libraries

---

## photo-backup.sh

A robust backup solution for photographers managing multiple storage devices. Safely merges content from two external disks with overlapping directory structures (e.g., both containing /Travel folders) into a consolidated backup on a Linux server while preserving unique files from both sources.

**Key Features:**
- Merge overlapping directory structures safely
- Prevent accidental deletions through protection filters
- Dry-run mode for testing changes
- Debug logging for troubleshooting
- Color-coded terminal output
- Smart cleanup of macOS temporary files
- Customizable paths and host configuration
- Comprehensive safety checks and validations

### Installation

```bash
# Download the script
curl -O https://raw.githubusercontent.com/jmerhar/photography/refs/heads/main/photo-backup.sh

# Make executable
chmod +x photo-backup.sh

# Verify installation
./photo-backup.sh -h
```

### Usage

**Basic Command:**
```bash
./photo-backup.sh \
  -1 /Volumes/PhotoStore \
  -2 /Volumes/MorePhotos \
  -H backup-server \
  -p /mnt/storage/photos
```

**Common Options:**
```
-n            Dry-run mode (show what would happen)
-d            Debug mode (show detailed command logging)
-l path.log   Custom log file location
-1 PATH       Primary source path
-2 PATH       Secondary source path
-H HOST       Backup server hostname
-p PATH       Destination path on server
```

**Example Scenarios:**

1. **Dry-run Test:**
   ```bash
   ./photo-backup.sh -n -d -l ~/backup-test.log
   ```

2. **Custom Configuration:**
   ```bash
   ./photo-backup.sh \
     -1 /mnt/camera-roll \
     -2 /mnt/archive \
     -H nas.example.com \
     -p /volume1/PhotoBackup \
     -l /var/log/custom-backup.log
   ```

3. **Debug Mode:**
   ```bash
   ./photo-backup.sh -d 2>&1 | tee debug-output.log
   ```

**Sample Output:**
```text
==> BEGIN BACKUP OPERATION - Thu Jun 13 14:00:00 CEST 2024
==> Source 1: /Volumes/PhotoStore
==> Source 2: /Volumes/MorePhotos
==> Destination: aurora:/mnt/storage/photos
==> Cleaning temporary files...
DEBUG: Running: find /Volumes/PhotoStore -name .DS_Store -delete -print
DEBUG: Running: dot_clean -v /Volumes/PhotoStore
==> Backing up /Volumes/PhotoStore to aurora
sent 12.34G bytes  received 156.78k bytes  8.23M bytes/sec
==> BACKUP COMPLETED SUCCESSFULLY - Thu Jun 13 16:30:00 CEST 2024
```

### Requirements

- **Bash** 4.0+ (macOS/Linux)
- **rsync** (for efficient file transfers)
- **SSH access** to backup server
- **dot_clean** (macOS - included by default)

---

## remove-sidecars.pl

I like to shoot with my camera in RAW+JPEG mode, in order to have high-quality raw photos, but also jpegs
for quick preview and to quickly send to my phone for example. Lightroom is smart enough to recognise
these jpegs as sidecars for the main raw photos, which means that they don't bother me much.

All is good then, but when my catalogue reached 100k+ photos, I realised that these sidecars were taking up
a lot of space on my hard drive, for no added benefit. When I tried to delete them I realised that Lightroom
had no feature to do that. So I decided to write a script for it. I ended up freeing 300+ GB of disk space.

### Usage

Make sure you have [perl](https://www.perl.org/get.html) installed. If you're on Mac or Linux, you should
already have it. You may need to install it on Windows.

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

If you're on Windows, or for whatever reason can't make the script executable, you can also run it like this:

```
$ perl remove-sidecars.pl /path/to/my/photos
```

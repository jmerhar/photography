#!/usr/bin/perl

use strict;
use warnings;
use 5.16.0;
use Data::Dumper qw(Dumper);

my @jpegs = qw( JPG jpg JPEG jpeg );
my @raws = qw( RW2 CR2 DNG ); # skipping lowercase dng because Pixel does HDR in jpeg only
my $files_to_delete = ();

sub traverse_tree {
    my ($dir) = @_;
    opendir(my $dh, $dir) || die "Can't open $dir: $!";

    my $files = {};
    while (readdir $dh) {
        next if m/^\.+$/; # skip . and ..

        my $filename = $_;
        my $path = "$dir/$filename";

        if (-d $path) {
            traverse_tree($path);
        } else {
            next unless $filename =~ m/^(.*)\.([^.]+)$/;
            $files->{$1}{$2} = 1;
        }
    }

    closedir($dh);
    process_dir($dir, $files);
}


sub process_dir {
    my ($dir, $files) = @_;

    for my $name (keys %$files) {
        my $extensions = $files->{$name};
        my $file = undef;

        for my $ext (@jpegs) {
            if ($extensions->{$ext}) {
                delete $extensions->{$ext};
                $file = "$dir/$name.$ext";
                last;
            }
        }

        next unless $file;

        for my $ext (keys %$extensions) {
            push @{ $files_to_delete->{$ext} }, $file;
        }
    }
}

sub format_size {
    my $size = shift;
    my $exp = 0;

    state $units = [qw(B KB MB GB TB PB)];

    for (@$units) {
        last if $size < 1024;
        $size /= 1024;
        $exp++;
    }

    return sprintf("%.2f %s", $size, $units->[$exp]);
}

my $root_dir = $ARGV[0] // '.';
traverse_tree($root_dir);

# print Dumper($files_to_delete);

my $total_size = 0;
my %ext_size;
for my $ext (@raws) {
    for my $file (@{ $files_to_delete->{$ext} }) {
        my $size = -s $file // 0;
        printf "Deleting %s (%s), a sidecar of %s\n", $file, format_size($size), $ext;
        $total_size += $size;
        $ext_size{$ext} += $size;
        unlink $file;
    }
    print "\n";
}

printf "In total %s of disk space was recovered.\n", format_size($total_size);
printf "%s of disk space was recovered from %d %s sidecars (on average %s per file).\n",
    format_size($ext_size{$_}),
    scalar @{ $files_to_delete->{$_} },
    $_,
    format_size($ext_size{$_} / @{ $files_to_delete->{$_} })
    for keys %ext_size;

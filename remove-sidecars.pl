#!/usr/bin/perl

use strict;
use warnings;
use 5.16.0;
use Data::Dumper qw(Dumper);

my $files_to_delete = {};
my @jpegs;
my @raws;

sub read_answer {
    my $answer = <STDIN>;
    chomp $answer;
    return $answer;
}

sub define_extensions {
    my $jpegs = 'JPG jpg JPEG jpeg';
    my $raws  = 'RW2 CR2 DNG dng';

    printf "Please specify a list of sidecar extensions [%s] ", $jpegs;
    @jpegs = split(' ', read_answer || $jpegs);

    printf "Please specify a list of raw photo extensions [%s] ", $raws;
    @raws = split(' ', read_answer || $raws);
}

sub traverse_tree {
    my ($dir) = @_;
    opendir(my $dh, $dir) || die "Can't open $dir: $!";
    printf "Scanning directory %s\n", $dir;

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

sub prompt {
    if (!%$files_to_delete) {
        print "\nNo sidecars found\n";
        exit;
    }

    print "\nFound sidecars of:\n";
    for my $ext (@raws) {
        next unless $files_to_delete->{$ext};
        printf "- %d %s files\n", scalar @{ $files_to_delete->{$ext} }, $ext;
    }
    print "\nWould you like to delete them? [y/N] ";

    exit unless lc(read_answer) eq "y";
}

sub delete_files {
    my $total_size = 0;
    my $ext_size;
    for my $ext (@raws) {
        for my $file (@{ $files_to_delete->{$ext} }) {
            my $size = -s $file // 0;
            printf "Deleting %s (%s), a sidecar of %s\n", $file, format_size($size), $ext;
            $total_size += $size;
            $ext_size->{$ext} += $size;
            # unlink $file;
        }
    }
    print_report($total_size, $ext_size);
}

sub print_report {
    my ($total_size, $ext_size) = @_;

    printf "\nIn total %s of disk space was recovered:\n", format_size($total_size);
    printf "- %s of disk space was recovered from %d %s sidecars (on average %s per file).\n",
        format_size($ext_size->{$_}),
        scalar @{ $files_to_delete->{$_} },
        $_,
        format_size($ext_size->{$_} / @{ $files_to_delete->{$_} })
        for keys %$ext_size;
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

define_extensions;
traverse_tree($ARGV[0] // '.');
prompt;
delete_files;


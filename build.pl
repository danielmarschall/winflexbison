# Copyright 2023 alex@staticlibs.net
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;
use Cwd qw(abs_path getcwd);
use Digest::file qw(digest_file_hex);
use File::Basename qw(basename dirname);
use File::Copy::Recursive qw(fcopy dircopy);
use File::Path qw(make_path remove_tree);
use File::Slurp qw(write_file);
use File::Spec::Functions qw(catfile);

my $root_dir = dirname(abs_path(__FILE__));


sub ensure_dir_empty {
  my $dir = shift;
  if (-d $dir) {
    remove_tree($dir) or die("$!");
  }
  make_path($dir) or die("$!");
}

sub file_sha256sum {
  my $file_path = shift;
  my $sha256 = digest_file_hex($file_path, "SHA-256");
  my $file_name = basename($file_path);
  my $contents = "$sha256  $file_name";
  write_file("$file_path.sha256", $contents) or die("$!");
  print("$contents\n");
}

sub configure {
  my $build_dir = shift;
  my $install_dir = shift;

  my $cmake_cmd = "cmake ..";
  $cmake_cmd .= " -DCMAKE_BUILD_TYPE=Release";
  $cmake_cmd .= " -DUSE_STATIC_RUNTIME=ON";
  $cmake_cmd .= " -DCMAKE_INSTALL_PREFIX=$install_dir";
  print("$cmake_cmd\n");
  chdir($build_dir);
  0 == system($cmake_cmd) or die("$!");
  chdir($root_dir);
}

sub make {
  my $build_dir = shift;

  my $build_cmd = "cmake --build .";
  $build_cmd .= " --config Release";
  print("$build_cmd\n");
  chdir($build_dir);
  0 == system($build_cmd) or die("$!");
  chdir($root_dir);
}

sub make_install {
  my $install_dir = shift;

  my $bin_dir = catfile($root_dir, "bin", "Release");
  dircopy(catfile($bin_dir, "data"), catfile($install_dir, "data")) or die("$!");
  fcopy(catfile($bin_dir, "win_flex.exe"), catfile($install_dir, "flex.exe")) or die("$!");
  fcopy(catfile($bin_dir, "win_bison.exe"), catfile($install_dir, "bison.exe")) or die("$!");
  fcopy(catfile($root_dir, "COPYING"), catfile($install_dir, "COPYING")) or die("$!");
  fcopy(catfile($root_dir, "README.md"), catfile($install_dir, "README.md")) or die("$!");

  my @exe_list = <$install_dir/*.exe>;
  for my $exe_path (@exe_list) {
    file_sha256sum($exe_path);
  }
}

my $build_dir = catfile($root_dir, "build");
ensure_dir_empty($build_dir);
my $out_dir = catfile($root_dir, "out");
ensure_dir_empty($out_dir);
my $install_dir = catfile($out_dir, "flex-$ENV{FLEX_VERSION}_bison-$ENV{BISON_VERSION}");
configure($build_dir, $install_dir);
make($build_dir);
make_install($install_dir);

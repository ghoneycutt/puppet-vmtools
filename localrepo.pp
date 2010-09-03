# Author: Cody Herriges
# Pulls a selection of packages from a full Centos 5 mirror and
# drops the packages into a requested location on the local machine
# if any packages are updated it then runs createrepo to generate
# a local yum repo.  The local repos are meant to allow PuppetMaster
# trainings to be ran in the event that internet connectivity is an
# issue.
#
# All package patterns in each local repo need to currently be with in the
# same resource.  This is due to the method of retrieving and cleaning
# up packages; each resource delaration is going to issues a `rsync
# --delete` with means that you will only get package from the final
# resource that runs.  Suboptimal, yes and I think I am going to solve
# this with a ruby manifest at some point.
#
# Example:
#   pkgsync { "base_pkgs":
#     pkglist  => "httpd*\nperl-DBI*\nlibart_lgpl*\napr*\nruby-rdoc*\nntp*\n",
#     repopath => "/var/yum/mirror/centos/5/os/i386",
#     source   => "::centos/5/os/i386/CentOS/",
#     notify   => Repobuild["base"]
#   }
#
#   repobuild { "base":
#     repopath => "${base}/mirror/centos/5/os/i386",
#   }

define pkgsync ($pkglist = $name, $source, $server = "mirrors.cat.pdx.edu", $syncer = "rsync", $syncops = "-rltDvzPH --delete --delete-after", $repopath) {

  file { "/tmp/${name}list":
    content => "${pkglist}",
    mode     => 644,
    owner    => puppet,
    group    => puppet,
    notify   => Exec["get_${name}"],
  }

  exec { "get_${name}":
    command => "${syncer} ${syncops} --include-from=/tmp/${name}list  --exclude=* ${server}${source} ${repopath}/RPMS",
    user    => puppet,
    group   => puppet,
    path    => "/usr/bin:/bin",
    onlyif  => "${syncer} ${syncops} -n --include-from=/tmp/${name}list  --exclude=* ${server}${source} ${repopath}/RPMS | grep 'rpm$'",
    require => [ File["${repopath}/RPMS"], File["/tmp/${name}list"] ],
  }
}


define repobuild ($repopath, $repoer = "createrepo", $repoops = "-C --update -p") {

  exec { "${name}_build":
    command     => "${repoer} ${repoops} ${repopath}",
    user        => puppet,
    group       => puppet,
    path        => "/usr/bin:/vin",
    refreshonly => true,
  }

}

class localpm {

$base = "/var/yum"

$directories = [ "${base}",
                 "${base}/mirror",
                 "${base}/mirror/epel",
                 "${base}/mirror/epel/5",
                 "${base}/mirror/epel/5/local",
                 "${base}/mirror/epel/5/local/i386",
                 "${base}/mirror/epel/5/local/i386/RPMS", 
                 "${base}/mirror/centos", 
                 "${base}/mirror/centos/5",
                 "${base}/mirror/centos/5/os", 
                 "${base}/mirror/centos/5/os/i386",
                 "${base}/mirror/centos/5/os/i386/RPMS", 
                 "${base}/mirror/centos/5/updates",
                 "${base}/mirror/centos/5/updates/i386",
                 "${base}/mirror/centos/5/updates/i386/RMPS", ]

File { mode => 644, owner => puppet, group => puppet }

file { $directories:
  ensure => directory,
  recurse => true,
}

Exec {
  user    => puppet,
  group   => puppet,
  path    => "/usr/bin:/bin",
}

pkgsync { "base_pkgs":
  pkglist  => "httpd*\nperl-DBI*\nlibart_lgpl*\napr*\nruby-rdoc*\nntp*\n",
  repopath => "${base}/mirror/centos/5/os/i386",
  source   => "::centos/5/os/i386/CentOS/",
  notify   => Repobuild["base"]
}

repobuild { "base":
  repopath => "${base}/mirror/centos/5/os/i386",
}

}

#exec {
#  "get_base":
#    cmd => "${syncops}::centos/5/os/i386/CentOS/ --include-from=${base}/ref/ospkgs.txt ${base}/mirror/centos/5/os/i386/RPMS && ${repoops} ${base}/mirror/centos/5/os/i386";
#  "get_updates":
#    cmd => "${syncops}::centos/5/updates/i386/RPMS/ --include-from=${base}/ref/updatespkgs.txt ${base}/mirror/centos/5/updates/i386/RPMS && ${repoops} ${base}/mirror/centos/5/updates/i386";
#  "get_epel":
#    cmd => "${syncops}::epel/5/i386/ --include-from=${base}/ref/epelpkgs.txt ${base}/mirror/epel/5/local/i386/RPMS && ${repoops} ${base}/mirror/epel/5/local/i386";
#}
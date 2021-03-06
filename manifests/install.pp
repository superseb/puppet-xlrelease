# == Class xlrelease::install
#
class xlrelease::install {

  $xlr_version             = $xlrelease::xlr_version
  $xlr_basedir             = $xlrelease::xlr_basedir
  $xlr_serverhome          = $xlrelease::xlr_serverhome
  $xlr_licsource           = $xlrelease::xlr_licsource
  $xlr_download_user       = $xlrelease::xlr_download_user
  $xlr_download_password   = $xlrelease::xlr_download_password
  $xlr_download_proxy_url  = $xlrelease::xlr_download_proxy_url
  $xlr_download_server_url = $xlrelease::xlr_download_server_url
  $xlr_wrapper_settings    = $xlrelease::xlr_wrapper_settings

  $install_type    = $xlrelease::install_type
  $install_java    = $xlrelease::install_java
  $java_home       = $xlrelease::java_home
  $os_user         = $xlrelease::os_user
  $os_group        = $xlrelease::os_group
  $tmp_dir         = $xlrelease::tmp_dir
  $puppetfiles_xlrelease_source = $xlrelease::puppetfiles_xlrelease_source

  #flow controll
  anchor{ 'xlr install': }
  -> anchor{ 'xlr server_install': }
  -> anchor{ 'xlr server_postinstall': }
  -> File['xlr conf dir link', 'xlr log dir link']
  -> File["$xlr_serverhome"]
  -> File["${xlr_serverhome}/scripts"]
  -> anchor{ 'xlr install_end': }


  #figure out the server install dir
  $server_install_dir   = "${xlr_basedir}/xl-release-${xlr_version}-server"

  # Make this a private class
  if $caller_module_name != $module_name {
    fail("Use of private class ${name} by ${caller_module_name}")
  }

  # install java packages if needed
  if str2bool($install_java) {
    case $::osfamily {
      'RedHat' : {
        $java_packages = ['java-1.7.0-openjdk']
        $unzip_packages = ['unzip']
        ensure_packages($java_packages)
        ensure_packages($unzip_packages)
      }
      'Debian' : {
        $java_packages = ['openjdk-7-jdk']
        $unzip_packages = ['unzip']
        ensure_packages($java_packages)
        ensure_packages($unzip_packages)
      }
      default  : {
        fail("${::osfamily}:${::operatingsystem} not supported by this module")
      }
    }
  }

  # user and group

  group { $os_group: ensure => 'present' }

  user { $os_user:
    ensure     => present,
    gid        => $os_group,
    managehome => false,
    home       => $xlr_serverhome
  }

  # base dir

  file { $xlr_basedir:
    ensure => directory,
    owner  => $os_user,
    group  => $os_group,
  }

  #the actual xl-release installation
  # we're only supporting puppetfiles for now
  case $install_type {
    'puppetfiles' : {

      $server_zipfile = "xl-release-${xlr_version}-server.zip"

      Anchor['xlr server_install']

      -> file { "${tmp_dir}/${server_zipfile}": source => "${puppetfiles_xlrelease_source}/${server_zipfile}" }

      -> file { $server_install_dir: ensure => directory, owner => $os_user, group => $os_group }

      -> exec { 'xlr unpack server file':
        command => "/usr/bin/unzip ${tmp_dir}/${server_zipfile};/bin/cp -rp ${tmp_dir}/xl-release-${xlr_version}-server/* ${server_install_dir}",
        creates => "${server_install_dir}/bin",
        cwd     => $tmp_dir,
        user    => $os_user
      }

      -> Anchor['xlr server_postinstall']
    }
    'download'    : {

    Anchor['xlr server_install']

    -> xlrelease_netinstall{ $xlr_download_server_url:
      owner          => $os_user,
      group          => $os_group,
      user           => $xlr_download_user,
      password       => $xlr_download_password,
      destinationdir => $xlr_basedir,
      proxy_url      => $xlr_download_proxy_url
    }

    -> Anchor['xlr server_postinstall']
    }
  default       : { fail('unsupported installation type')
    }
  }

  file { 'xlr log dir link':
    ensure => link,
    path   => '/var/log/xl-release',
    target => "${server_install_dir}/log";
  }

  file { 'xlr conf dir link':
    ensure => link,
    path   => '/etc/xl-release',
    target => "${server_install_dir}/conf"
  }

# setup homedir
  file { $xlr_serverhome:
    ensure => link,
    target => $server_install_dir,
    owner  => $os_user,
    group  => $os_group
  }

  create_resources('xlrelease::resources::wrappersetting', $xlr_wrapper_settings)

  case $xlr_licsource {
    /^http/ : {
      File[$xlr_serverhome]

      -> xlrelease_license_install{ $xlr_licsource:
        owner                => $os_user,
        group                => $os_group,
        user                 => $xlr_download_user,
        password             => $xlr_download_password,
        destinationdirectory => "${xlr_serverhome}/conf"
      }
    }
    /^puppet/ : {
      File[$xlr_serverhome]

      -> file{"${xlr_serverhome}/conf/xl-release-license.lic":
        owner  => $os_user,
        group  => $os_group,
        source => $xlr_licsource,
      }
    }
    undef   : {}
    default : { fail('xlr_licsource input unsupported')}
  }

  file { "${xlr_serverhome}/scripts":
    ensure => directory,
    owner  => $os_user,
    group  => $os_group
  }

  if versioncmp($xlr_version , '4.9.99') < 0 {
    File["${xlr_serverhome}/scripts"] ->
    file { '/etc/init.d/xl-release':
      content => template("xlrelease/xl-release-initd-${::osfamily}.erb"),
      owner   => 'root',
      group   => 'root',
      mode    => '0700'
    } -> Anchor['xlr install_end']
  } else {
    File["${xlr_serverhome}/scripts"] ->
    ini_setting { 'forkhack':
      path    => "${xlr_serverhome}/conf/xlr-wrapper-linux.conf",
      setting => 'wrapper.fork_hack',
      value   => 'true',
    } ->
    exec {"/bin/echo ${os_user}|${xlr_serverhome}/bin/install-service.sh":
      unless => "/usr/bin/test -f /etc/init.d/xl-release",
    } -> Anchor['xlr install_end']
  }
}

define hubot::bot (
  $ensure='present',
  $rooms,
  $username,
  $password,
  $adapter='xmpp',
  $script_source='puppet://hubot/scripts/',
  $options=false
) {
  $dir_ensure = $ensure ? {
    'present' => 'directory',
    default   => $ensure
  }

  file { "${hubot::params::basedir}/${name}":
    ensure  => directory,
    notify  => Exec["create-hubot::${name}"]
  }

  exec { "create-hubot::${name}":
    command => "/usr/local/bin/hubot -c ${hubot::params::basedir}/${name}",
    creates => "${hubot::params::basedir}/${name}/bin/hubot"
  }

  exec { "build-hubot-deps::${name}":
    command => "sudo node-gyp rebuild",
    cwd => "${hubot::params::basedir}/${name}/node_modules/hubot-xmpp/node_modules/node-xmpp/node_modules/node-expat",
    creates => "${hubot::params::basedir}/${name}/node_modules/hubot-xmpp/node_modules/node-xmpp/node_modules/node-expat/build",
    require => Nodejs::Npm["${hubot::params::basedir}/${name}:hubot-${adapter}"]
  }

  exec { "bootstrap-hubot::${name}":
    cwd         => "${hubot::params::basedir}/${name}",
    command     => "/usr/bin/npm install",
    refreshonly => true,
    subscribe   => Exec["create-hubot::${name}"]
  }

  nodejs::npm { "${hubot::params::basedir}/${name}:hubot-${adapter}":
    ensure  => present,
    require => Exec["bootstrap-hubot::${name}"]
  }

  file { "${hubot::params::basedir}/${name}/scripts":
    ensure  => $dir_ensure,
    recurse => true,
    source  => $script_source
  }

  file { "${hubot::params::basedir}/${name}/instance_config":
    ensure  => $ensure,
    content => template('hubot/instance_config.erb'),
    notify  => Class['hubot::service']
  }

  file { "${hubot::params::basedir}/${name}/launch.sh":
    ensure  => $ensure,
    content => template('hubot/launch.erb'),
    mode    => 0744,
    notify  => Class['hubot::service']
  }

  file { "/etc/init/hubot-${name}.conf":
    ensure  => present,
    content => template('hubot/upstart.erb'),
    notify  => Class['hubot::service']
  }

  file { "/etc/init.d/hubot-${name}":
    ensure  => symlink,
    target  => "/etc/init/hubot-${name}.conf"
  }

  service { "hubot-${name}":
    provider  => upstart,
    require   => File["/etc/init/hubot-${name}.conf"],  
    tag       => 'hubot'
  }
}
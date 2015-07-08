require 'pathname'

Puppet::Type.newtype(:xlrelease_repo_driver_netinstall) do

  desc 'download and unpack a database driver archive file from the interwebs'

  ensurable do
    desc "xlrelease_repo_driver_netinstall resource state"

    defaultto(:present)

    newvalue(:present) do
      provider.create
    end

    newvalue(:absent) do
      provider.destroy
    end
  end


  newparam(:lib_dir) do
    desc 'xlrelease_plugin dir'

    defaultto '/opt/xl-release/xl-release-server/lib'

    validate do |value|

      fail('invalid pathname') unless Pathname.new(value).absolute?

    end
  end

  newparam(:proxy_url) do
    desc 'http proxy url'
  end

  newparam(:user) do
    desc 'download user'
    defaultto 'download'
  end

  newparam(:password) do
    desc 'download password'
    validate do |value|
      fail('xebialabs download password should be set') if value.nil?
    end
  end

  newparam(:url, :namevar => true ) do
    desc 'the base url where the plugins can be found'
  end


  newproperty(:owner) do
    desc 'the owner setting of the plugin jar file'
    defaultto 'xlrelease'
  end

  newproperty(:group) do
    desc 'the group setting of the plugin jar file'
    defaultto 'xlrelease'
  end



end
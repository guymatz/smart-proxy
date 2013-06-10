#require 'rubygems'
require 'rkerberos'
require 'krb5_auth'

module Proxy::Kerberos

  def init_krb5_ccache
    begin
      krb5 = Kerberos::Krb5.new
      ccache = Kerberos::Krb5::CredentialsCache.new
    rescue => e
      logger.error "Failed to create kerberos objects: #{e}"
      raise #{self.class.superclass}::Error.new("#{self.class.superclass} Failed to create kerberos objects: #{e}")
    end

    logger.info "Requesting credentials for Kerberos principal #{@tsig_principal} using keytab #{@tsig_keytab}"
    begin
      krb5.get_init_creds_keytab @tsig_principal, @tsig_keytab, nil, ccache
    rescue => e
      logger.error "Failed to initialise credential cache from keytab: #{e}"
      raise #{self.class}::Error.new("#{self.class} Unable to initialise Kerberos: #{e}")
    end
    logger.debug "Kerberos credential cache initialised with principal: #{ccache.primary_principal}"
  end

end

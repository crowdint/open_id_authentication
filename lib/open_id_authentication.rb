module OpenIdAuthentication
  protected
    # OpenIDs are expected to begin with http:// or https://
    def open_id?(user_name) #:doc:
      (Object.const_defined?(:OpenID) && user_name =~ /^https?:\/\//i) || params[:open_id_complete]
    end

    def authenticate_with_open_id(identity_url, &block) #:doc:
      if params[:open_id_complete].nil?
        begin_open_id_authentication(identity_url, &block)
      else
        complete_open_id_authentication(&block)
      end
    end


  private
    def begin_open_id_authentication(identity_url)
      open_id_response = open_id_consumer.begin(identity_url)

      case open_id_response.status
      when OpenID::FAILURE
        yield :missing, identity_url
      when OpenID::SUCCESS
        redirect_to(open_id_response.redirect_url(
          root_url, open_id_response.return_to(
            "#{request.protocol + request.host_with_port + request.request_uri}?open_id_complete=1"
          )
        ))
      end
    end
  
    def complete_open_id_authentication
      open_id_response = open_id_consumer.complete(params)

      case open_id_response.status
      when OpenID::CANCEL
        yield :canceled, open_id_response.identity_url
      when OpenID::FAILURE
        logger.info "OpenID authentication failed: #{open_id_response.msg}"
        yield :failed, open_id_response.identity_url
      when OpenID::SUCCESS
        yield :successful, open_id_response.identity_url
      end      
    end

    def open_id_consumer
      OpenID::Consumer.new(session, OpenID::FilesystemStore.new(RAILS_ROOT + "/tmp/openids"))
    end
end
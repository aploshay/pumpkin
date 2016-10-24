# new class for imago to handle purl redirection
class PurlController < ApplicationController

  def render_404
    render :file => "/public/404.html",  :status => 404
  end

  def default
    begin
      realid = ScannedResource.where(source_metadata_identifier: params[:id]).first.id
    rescue
      render_404 and return
    end

    redirect_to("#{request.protocol}#{request.host_with_port}/concern/scanned_resources/#{realid}")
  end

end

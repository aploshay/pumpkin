# new class for imago to handle purl redirection
class PurlController < ApplicationController
  def render_404
    respond_to do |f|
      f.html { render file: '/public/404.html', status: 404 }
      f.json { render json: { error: 'not_found' }.to_json, status: 404 }
    end
  end

  def default
    begin
      set_object
      realid = @object.id
    rescue
      render_404 && return
    end
    url = "#{request.protocol}#{request.host_with_port}/concern/#{@subfolder}/#{realid}"
    respond_to do |f|
      f.html { redirect_to url }
      f.json { render json: { url: url }.to_json }
    end
  end

  private

    OBJECT_LOOKUPS = {
      FileSet => { match_pattern: /^\w{3}\d{4}-\d{1}-\d{4}/, search_attribute: :label },
      ScannedResource => { match_pattern: /^\w{3}\d{4}$/, search_attribute: :source_metadata_identifier },
      MultiVolumeWork => { match_pattern: /^\w{3}\d{4}$/, search_attribute: :source_metadata_identifier }
    }
    def set_object
      OBJECT_LOOKUPS.each do |klass, values|
        if params[:id].match values[:match_pattern]
          @object = klass.where(values[:search_attribute] => params[:id]).first
        end
        break if @object
      end
      @subfolder = @object.class.to_s.pluralize.underscore
    end
end

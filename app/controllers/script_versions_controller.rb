class ScriptVersionsController < ApplicationController

	before_filter :authenticate_user!, :except => [:index]
	before_filter :authorize_by_script_id, :except => [:index]

	layout 'scripts', only: [:index]

	def index
		@script = Script.find(params[:script_id], :include => [:script_versions])
	end

	def new
		@script_version = ScriptVersion.new
		if !params[:script_id].nil?
			@script = Script.find(params[:script_id]) 
			@script_version.script = @script
			previous_script = @script.script_versions.last
			@script_version.code = previous_script.code
			@script_version.additional_info = previous_script.additional_info
			@script_version.additional_info_markup = previous_script.additional_info_markup
			render :layout => 'scripts'
		else
			@script_version.script = Script.new
		end
	end

	def create

		@script_version = ScriptVersion.new
		@script_version.assign_attributes(script_version_params)

		if params[:script_id].nil?
			@script = Script.new
			@script.user = current_user
			@script_version.version = "1.#{Time.now.utc.strftime('%Y%m%d%H%M%S')}"
			@script.code_updated_at = Time.now
		else
			@script = Script.find(params[:script_id])
			previous_script_version = @script.script_versions.last
			# update the version number and code_updated_at if the code changed
			if previous_script_version.code == @script_version.code
				@script_version.version = previous_script_version.version
			else
				@script_version.version = "1.#{Time.now.utc.strftime('%Y%m%d%H%M%S')}"
				@script.code_updated_at = Time.now
			end
		end

		@script_version.script = @script
		@script_version.rewritten_code = @script_version.calculate_rewritten_code 
		@script.apply_from_script_version(@script_version)

		# ensure all validations are run - short circuit the OR
		if !@script.valid? | !@script_version.valid?
			if @script.new_record?
				render :new
			else
				# get the original script for display within the scripts layout
				@script.reload
				render :new, :layout => 'scripts'
			end
			return
		end

		@script.script_versions << @script_version
		@script.save!

		flash[:notice] = 'Your script thas been submitted for assessment. Watch for discussions on your script for the result.' if @script_version.accepted_assessment

		redirect_to @script
	end

private

	def script_version_params
		params.require(:script_version).permit(:code, :changelog, :additional_info, :additional_info_markup, :accepted_assessment)
	end

end

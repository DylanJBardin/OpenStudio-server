# BatchRunLocal runs simulations in an in memory queue without using R.
# Right now this is attached to an analysis--need to verify if this is
# what we need to do.

class Analysis::BatchRunLocal
  include Analysis::Core

  def initialize(analysis_id, analysis_job_id, options = {})
    defaults = {
      skip_init: false,
      data_points: [],
      run_data_point_filename: 'run_openstudio.rb',
      problem: {}
    }.with_indifferent_access # make sure to set this because the params object from rails is indifferential
    @options = defaults.deep_merge(options)

    @analysis_id = analysis_id
    @analysis_job_id = analysis_job_id
  end

  # Perform is the main method that is run in the background.  At the moment if
  # this method crashes it will be logged as a failed delayed_job and will fail
  # after max_attempts.
  def perform
    @analysis = Analysis.find(@analysis_id)

    # get the analysis and report that it is running
    @analysis_job = Analysis::Core.initialize_analysis_job(@analysis, @analysis_job_id, @options)

    # reload the object (which is required) because the subdocuments (jobs) may have changed
    @analysis.reload

    begin
      if @options[:data_points].empty?
        logger.info 'No data points were passed into the options, therefore checking which data points to run'

        # queue up the simulations

        @analysis.data_points.where(status: 'na').each do |dp|
          logger.info "Adding #{dp.uuid} to simulations queue"
          a = RunSimulateDataPoint.new(dp.id)
          a.delay(queue: 'simulations').perform
        end
      end
    rescue => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      logger.error log_message
      @analysis.status_message = log_message
      @analysis.save!
    end
  end

  # Since this is a delayed job, if it crashes it will typically try multiple times.
  # Fix this to 1 retry for now.
  def max_attempts
    1
  end

  # Return the logger for the delayed job
  def logger
    Delayed::Worker.logger
  end

  # Return the Ruby system call string for ease
  def sys_call_ruby
    "cd #{APP_CONFIG['sim_root_path']} && #{APP_CONFIG['ruby_bin_dir']}/ruby"
  end
end

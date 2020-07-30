module ToolingInvoker
  class Worker
    include Mandate

    SLEEP_TIME = 1 #0.1

    def initialize
    end

    def call
      loop do
        begin
          job = check_for_job
          if job 
            handle_job(job)
          else
            sleep(SLEEP_TIME)
          end
        rescue => e
          p "Top level error"
          p e.message
          p e.backtrace

          sleep(SLEEP_TIME)
        end
      end
    end

    private

    # This will raise an exception if something other than 
    # a 200 or a 404 is found.
    def check_for_job
      resp = RestClient.get(
        "#{Configuration.orchestrator_address}/jobs/next"
      )
      p resp.body
      job_data = JSON.parse(resp.body)
      p job_data

      klass = case job_data['type']
      when 'test_runner'
        TestRunnerJob
      else 
        raise "Unknown job: #{job_data['type']}"
      end

      klass.new(
        job_data['id'],
        job_data['language'],
        job_data['exercise'],
        job_data['s3_uri'],
        job_data['container_version'],
        job_data['execution_timeout']
      )
    rescue RestClient::NotFound
      nil
    end

    def handle_job(job)
      Configuration.invoker.(job)
      RestClient.patch(
        "#{Configuration.orchestrator_address}/jobs/#{job.id}", 
        job.to_h
      )
    rescue => e
      p e.message
      p e.backtrace
    end

    def log(message)
      puts "* #{message}"
    end
  end
end


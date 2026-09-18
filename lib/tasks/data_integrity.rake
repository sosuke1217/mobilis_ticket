namespace :data_integrity do
  desc "Check reservation and ticket data integrity and notify admins only when issues exist"
  task check: :environment do
    issues = DataIntegrityChecker.call

    if issues.empty?
      puts "[DATA INTEGRITY] ok"
    else
      DataIntegrityMailer.issues_found(issues).deliver_now
      summary = issues.map { |name, issue| "#{name}=#{issue[:count]}" }.join(" ")
      puts "[DATA INTEGRITY] issues_found #{summary}"
    end
  rescue StandardError => error
    ErrorHandlingService.log_error(error, source: "data_integrity#check", job: "data_integrity:check")
    raise
  end
end

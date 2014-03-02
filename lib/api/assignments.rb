require 'api/assignments/xapi'

class ExercismAPI < Sinatra::Base
  get '/assignments/demo' do
    Xapi.get("demo")
  end

  get '/assignments/:language/:slug' do |language, slug|
    Xapi.get("exercises", language, slug)
  end

  get '/user/assignments/completed' do
    require_user
    {assignments: current_user.completed}.to_json
  end

  get '/user/assignments/current' do
    require_user
    Xapi.get("exercises", key: current_user.key)
  end

  get '/user/assignments/next' do
    halt 410, {error: "`peek` is deprecated. `fetch` always delivers the next exercise."}.to_json
  end

  get '/user/assignments/restore' do
    require_user
    Xapi.get("exercises", "restore", key: current_user.key)
  end

  post '/user/assignments' do
    request.body.rewind
    data = request.body.read
    if data.empty?
      halt 400, {:error => "Must send key and code as json."}.to_json
    end
    data = JSON.parse(data)
    user = User.where(key: data['key']).first
    begin
      LogEntry.create(user: user, body: data.merge(user_agent: request.user_agent).to_json)
    rescue => e
      # ignore failures
    end
    unless user
      message = <<-MESSAGE
      Beloved user,

      We have changed your API key (and everyone else's).

      You will need to log out from the exercism command line client
      (`exercism logout`) and log back in using the new API key in
      your account on the website.

      Sorry about the inconvenience!
      MESSAGE
      halt 401, {:error => message}.to_json
    end

    begin
      attempt = Attempt.new(user, data['code'], data['path'])
      # TODO: refactor to ask about validity
      attempt.exercise
      attempt.validate!
    rescue Exercism::UnknownExercise, Exercism::UnknownLanguage => e
      halt 400, {:error => e.message}.to_json
    end

    if attempt.duplicate?
      halt 400, {:error => "This attempt is a duplicate of the previous one."}.to_json
    end

    attempt.save
    Notify.everyone(attempt.submission.reload, 'code', user)

    status 201
    pg :attempt, locals: {submission: attempt.submission}
  end

  delete '/user/assignments' do
    require_user
    begin
      Unsubmit.new(current_user).unsubmit
    rescue Unsubmit::NothingToUnsubmit
      halt 404, {error: "Nothing to unsubmit."}.to_json
    rescue Unsubmit::SubmissionHasNits
      halt 403, {error: "The submission has nitpicks, so can't be deleted."}.to_json
    rescue Unsubmit::SubmissionDone
      halt 403, {error: "The submission has been already completed, so can't be deleted."}.to_json
    rescue Unsubmit::SubmissionTooOld
      halt 403, {error: "The submission is too old to be deleted."}.to_json
    end
    status 204
  end

end


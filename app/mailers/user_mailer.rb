class UserMailer < ActionMailer::Base
  default from: 'notifications@lopezlawnandlandscape.com'

  def welcome_email(user)
    @user = user
    @url  = 'http://lopezlawnandlandscape.com/login'
    mail(to: @user.email, subject: 'Welcome to Lopez Lawn and Landscape')
  end
end

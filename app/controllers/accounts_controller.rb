class AccountsController < ApplicationController
  skip_before_filter :authenticate_user, except: %w(edit update)

  load_and_authorize_parent :person, permit: :edit, only: %w(edit update)

  def show
    if params[:person_id]
      redirect_to person_account_path(params[:person_id])
    else
      redirect_to new_account_path
    end
  end

  def new
    # TODO pass in verification
    if params[:email]
      @verification = Verification.new
      render action: 'new_by_email'
    elsif params[:phone]
      @verification = Verification.new
      render action: 'new_by_mobile'
    elsif params[:birthday]
      @verification = Verification.new
      render action: 'new_by_birthday'
    elsif Setting.get(:features, :sign_up)
      @signup = Signup.new
    else
      render text: I18n.t('pages.not_found'), layout: true, status: :not_found
    end
  end

  def create
    if params[:signup]
      @signup = Signup.new(params[:signup])
      if @signup.save
        if @signup.verification_sent?
          render text: t('accounts.verification_email_sent'), layout: true
        elsif @signup.approval_sent?
          render text: t('accounts.pending_approval'), layout: true
        end
      else
        render action: 'new'
      end
    elsif params[:verification]
      params.permit! # FIXME
      @verification = Verification.new(params[:verification])
      if @verification.save
        # TODO appropriate message for type of verification
        render text: t('accounts.verification_email_sent'), layout: true
        #render text: t('accounts.verification_message_sent'), layout: true
        #render text: t('accounts.submission_will_be_reviewed'), layout: true
      else
        render action: 'new_by_email'
      end
    else
      @signup = Signup.new
      flash[:warning] = t('accounts.fill_required_fields')
      render action: 'new'
    end
  end

  def verify_code
    v = Verification.pending.find(params[:id])
    if v.check!(params[:code])
      if v.people.count > 1
        session[:select_from_people] = v.people.all
        redirect_to select_account_path
      else
        person = v.people.first
        session[:logged_in_id] = person.id
        flash[:sticky_notice] = true
        if v.mobile_phone?
          flash[:warning] = t('accounts.set_your_email')
        else
          flash[:warning] = t('accounts.set_your_email_may_be_different')
        end
        redirect_to edit_person_account_path(person)
      end
    else
      render text: t('accounts.wrong_code'), layout: true, status: :bad_request
    end
  end

  def edit
  end

  def update
    if @person.update_attributes(person_params)
      flash[:notice] = t('Changes_saved')
      redirect_to @person
    else
      render action: 'edit'
    end
  end

  def select
    if session[:select_from_people]
      @people = session[:select_from_people]
      if request.post? and @person = @people.detect { |p| p.id == params[:id].to_i }
        session[:logged_in_id] = @person.id
        session[:select_from_people] = nil
        flash[:warning] = t('accounts.must_set_email_pass')
        redirect_to edit_person_account_path(@person)
      end
    else
      render text: t('Page_no_longer_valid'), layout: true, status: :gone
    end
  end

  private

  def person_params
    params.require(:person).permit(:email, :password, :password_confirmation)
  end

  def check_ssl
    unless request.ssl? or !Rails.env.production? or !Setting.get(:features, :ssl)
      redirect_to protocol: 'https://', from: params[:from]
      return
    end
  end
end

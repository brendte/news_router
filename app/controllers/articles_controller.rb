class ArticlesController < ApplicationController
  # GET /articles
  # GET /articles.json
  def index
    @articles = Article.order(:updated_at).page params[:page]

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @articles }
    end
  end
end

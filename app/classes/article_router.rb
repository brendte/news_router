# routes a specific article to any user that has a query that matches the article above the user's selected
# match threshold
class ArticleRouter
  include Singleton

  DEFAULT_THRESHOLD = 0.5

  # routes a specific article to any user that has a query that matches the article above the user's selected
  # match threshold OR routes a specific article to a specific user based on a single query iff the threshold is
  # reached
  def route_article(article, queries)
    queries = [queries] unless queries.is_a?(Array)
    queries.each do |query|
      score = article.score_against(query)[0][1]
      threshold = query.threshold ? query.threshold : ArticleRouter::DEFAULT_THRESHOLD
      if score >= threshold
        query.user.articles << article unless query.user.articles.exists?(article)
      end
    end
  end

  # route all articles that have been gathered by Crawler and Indexer since the last time
  # ArticleRouter ran
  def route_new
    queries = Query.all
    Article.unrouted.each do |article|
      self.route_article(article, queries)
      article.routed = true
      article.save
    end
  end

  # route all articles to a specific user if the query matches and meets the threshold; called whenever a user creates a new query
  def route_on_new_query(query)
    Article.all.each do |article|
      self.route_article(article, query)
    end
  end
end
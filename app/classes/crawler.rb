# This class "crawls" news articles by FeedEntries from know RSS Feeds (see db/seeds for list of currently used RSS feeds),
# fetching the full article based on the url in the FeedEntry, and creating an Article which contains the article's full body
# as extracted by the (awesome!) AlchemyAPI (http://www.alchemyapi.com/api/text/proc.html)
class Crawler
  include Singleton

  # call to update all Feeds with new FeedEntries and create Articles from the FeedEntries, primarily exists for back-ground CRAWL_INDEX_ROUTE job to call
  def crawl
    update_all_feeds
    fetch_and_store_articles
  end

  private

  # use an instance of Rails ActionController::HTML::FullSanitizer to remove all HTML tags from the FeedEntry.summary
  def initialize
    @html_sanitizer = HTML::FullSanitizer.new
  end

  # remove leading and trailing whitespace from a string
  # s: string
  # return: string
  def clean_string(s)
    s.lstrip! if s
    s.rstrip! if s
    s
  end

  # for every Feed we monitor, fetch the feed and parse it for FeedEntries, which will be used in fetch_and_store_articles
  # to fetch and store Articles. this uses the feedzirra (https://github.com/pauldix/feedzirra) gem to fetch and parse the rss feeds
  def update_all_feeds
    Feed.all.each do |feed_entry|
      begin
        feed = Feedzirra::Feed.fetch_and_parse(feed_entry.feed_url)
      rescue Exception => e
        Rails.logger.error "Feedzirra threw an error on feed_entry #{feed_entry.id}: #{e.inspect}"
      end
      if !feed.blank? && !feed.is_a?(Fixnum) && !feed.entries.blank?
        feed.entries.each do |entry|
          begin
            entry.summary = @html_sanitizer.sanitize(entry.summary) unless entry.summary.blank?
            next if entry.title.blank? || entry.summary.blank? || entry.url.blank? || entry.id.blank? || entry.published.blank?
            guid = Base64.urlsafe_encode64(OpenSSL::Digest::MD5.digest(entry.id))
            unless FeedEntry.exists?(guid: guid)
              FeedEntry.create(title: clean_string(entry.title), summary: clean_string(entry.summary), url: clean_string(entry.url), published_at: entry.published, guid: guid, fetched: false)
            end
          rescue Exception => e
            Rails.logger.error "Caught an error on inserting feed_entry #{entry.id}: #{e.inspect}"
          end
        end
      end
    end
  end

  # go out and grab the full body text of the article linked by a FeedEntry.
  # body text is extracted by the (awesome!) AlchemyAPI (http://www.alchemyapi.com/api/text/proc.html)
  # calls to Alchemy are performed using the Typhoeus gem (https://github.com/typhoeus/typhoeus) because it's super fast (using curl bindings)
  # and allows for many concurrent calls
  def fetch_and_store_articles
    hydra = Typhoeus::Hydra.new(max_concurrency: 20)
    FeedEntry.where(fetched: false).each do |feed_entry|
      begin
        request = Typhoeus::Request.new("http://access.alchemyapi.com/calls/url/URLGetText?apikey=2dca9a7577657ed330d2a99e2744a167f043b3c6&outputMode=json&url=#{feed_entry.url}")
        request.on_complete &store_article(feed_entry)
        hydra.queue(request)
      rescue Exception => e
        Rails.logger.error "Caught an error trying to queue feed_entry #{feed_entry.id} for Typhoeus call: #{e.inspect}"
        next
      end
    end
    begin
      hydra.run
    rescue Exception => e
      Rails.logger.error "Hydra threw an error: #{e.inspect}"
    end
  end

  # callback for calls made to AlchemyAPI with Typhoeus. when the call returns, this return body is parsed and the article's body
  # text is stored as a new Article. also note, that we store the article's euclidean length as 0.0 at this point as it will be
  # calculated during later indexing
  # feed_entry: FeedEntry
  # return: Proc
  def store_article(feed_entry)
    Proc.new do |body_response|
      begin
        if body_response.code == 200
          body = body_response.body['text'] ? JSON.parse(body_response.body)['text'] : ''
          if body.blank?
            raise "Alchemy returned a blank body for feed_entry: #{feed_entry.id}"
          else
            if feed_entry.create_article(body: body, indexed: false, euclidean_length: 0.0, routed: false)
              mark_as_fetched(feed_entry)
            else
              raise "Couldn't save the article for feed_entry: #{feed_entry.id}"
            end
          end
        else
          raise "Alchemy didn't show you any love for feed_entry: #{feed_entry.id}"
        end
      rescue Exception => e
         Rails.logger.error "Something went wrong in Typhoeus callback for feed_entry #{feed_entry.id}: #{e}"
      end
    end
  end

  # once we've successfully fetched and stored an article, mark it as fetched in the db, so we don't keep trying to fetch it
  # TODO: future enhancement here would be to take into account updated articles, so that we can refresh the Article body and reindex
  # feed_entry: FeedEntry
  def mark_as_fetched(feed_entry)
    begin
      feed_entry.fetched = true
      feed_entry.save
    rescue Exception => e
      Rails.logger.error "Error trying to update status of feed_entry #{feed_entry.id} to 'fetched': #{e.inspect}"
    end
  end

end
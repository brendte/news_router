require 'mongo'

# maintains the MongoDB connections. uses free MongoDB PAAS https://www.mongohq.com. we store the dictionary and postings lists for the corpus of Articles
# in Mongo due to it's flexible, fairly fast and efficient, JSON-based binary data model, in which we can closely model these data structures
# as they would be if we used in-memory arrays, linked lists and block storage (without all the pain and suffering of doing it this way :)
class MongoClient

  class << self
    attr_reader :db_connection
  end

  def self.get_connection
    return @db_connection if @db_connection
    mongo_url = URI.parse(ENV['MONGOHQ_URL'])
    @mongo_client = Mongo::MongoClient.new(mongo_url.host, mongo_url.port)
    @db_connection = @mongo_client.db(mongo_url.path.delete('/'))
    @db_connection.authenticate(mongo_url.user, mongo_url.password)
    @db_connection
  end

end
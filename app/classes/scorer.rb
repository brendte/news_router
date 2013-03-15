# Provides all functionality to compute tf-idf weights of terms, and score vectors of terms against each other
# using cosine similarity
# Any Model referenced in this class must include Indexable
class Scorer
  include Singleton

  # class method to calculate the euclidean length of a document given a term frequency list
  # document_vector: {string: integer}
  # return: float
  def self.euclidean_length(document_vector)
    Math.sqrt(document_vector.values.reduce(0) {|acc, tf| acc + tf**2})
  end

  # score a single document against a single query on-the-fly; both parameters are instances of Models that include the
  # document_instance: Model. returns the normalized cosine similarity score
  # query_instance: Model
  # return: [[integer, float]]
  def score_one(document_instance, query_instance)
    db = MongoClient.get_connection
    resource_to_match_against = document_instance.class
    dictionary = db["#{resource_to_match_against}_dictionary"]

    score = 0.0
    n = resource_to_match_against.count # number of documents in the collection
    # generate the term frequency list for document on the fly and use it to
    document_tfs = Indexer.instance.generate_term_frequency_list(document_instance.body)

    # generate the term list for query on the fly; use it to and the document's term frequency list to calculate
    # cosine similarity
    Indexer.instance.generate_term_list(query_instance.body).each do |term|
      tf = document_tfs[term]

      unless tf.blank?
        word_listing = dictionary.find_one({word: term})
        df = word_listing['df']
        wf = tfidf(tf, df, n)
        score += wf
      end
    end

    euclidean_length = document_instance.euclidean_length
    [[document_instance.id, score/euclidean_length]] # normalized cosine similarity
  end

  # score all documents of a Model class against a single query; both parameters are instances of Models that include the
  # document_instance: Model.class
  # query_instance: Model
  # return: [[integer, float]]
  #TODO: future enhancement: refactor this to call into score_one to avoid code duplication
  def score_all(document_resource, query_instance)
    # get a db connection, and get references to the dictionary and postings collections
    db = MongoClient.get_connection
    resource_to_match_against = document_resource
  	dictionary = db["#{resource_to_match_against}_dictionary"]
  	postings = db["#{resource_to_match_against}_postings"]

    scores = {}
    n = resource_to_match_against.count # number of documents in the collection

    # generate the term list for query on the fly; use it to and the document's postings from MongoDB to calculate
    # cosine similarity between the query and each document
    Indexer.instance.generate_term_list(query_instance.body).each do |term|
      word_listing = dictionary.find_one({word: term})
      word_id = word_listing.blank? ? nil : word_listing['_id']
      unless word_id.blank?
        postings_list = postings.find_one({word_id: word_id})
        postings_list = postings_list['postings'] unless postings_list.blank?
        postings_list.each do |posting|
          document_id = posting['document_id']
          tf = posting['tf']
          df = word_listing['df']
          wf = tfidf(tf, df, n)
          if scores.has_key?(document_id)
            scores[document_id] += wf
          else
            scores[document_id] = wf
          end
        end
      end
    end

    scores.map do |document_id, raw_score|
      euclidean_length = resource_to_match_against.send(:where, {id: document_id}).first.euclidean_length
      normalized_score = raw_score/euclidean_length
      [document_id, normalized_score] # normalized cosine similarity
    end
  end

  # calc idf
  def idf(n, df)
    Math.log10(n/df)
  end

  # calc tf-idf
  def tfidf(tf, df, n)
    tf * idf(n, df)
  end

end
# Index each document by creating dictionary and postings lists for each term in the document.
# Any Model referenced in this class must include Indexable
# The dictionary entry for a term maintains
# a field for the document frequency of that term in the document collection. The postings lists maintain a "pointer"
# to a word in the dictionary, as well as an array of postings. Each entry in the postings array contains the id of the
# Article in which the term appears, and the term frequency of the term in that document
# Dictionary example:
#{
#  _id: ObjectId("5141287a85b9ca0002000003"),
#  word: "former",
#  df: 768
#}
#
#Postings example:
#{
#  _id: ObjectId("51413c6285b9ca0002010b6e"),
#  postings: [
#    {
#      document_id: 2686,
#      tf: 1
#    },
#    {
#      document_id: 3702,
#      tf: 1
#    }
#  ],
#  word_id: ObjectId("51413c6285b9ca0002010b6d")
#}
class Indexer
  include Singleton

  # stop word list built using data from http://dev.mysql.com/doc/refman/5.5/en/fulltext-stopwords.html and http://www.textfixer.com/resources/common-english-words.txt
  STOP_WORDS = 'a,able,about,across,after,all,almost,also,am,among,an,and,any,are,as,at,be,because,been,but,by,can,cannot,could,dear,did,do,does,either,else,ever,every,for,from,get,got,had,has,have,he,her,hers,him,his,how,however,i,if,in,into,is,it,its,just,least,let,like,likely,may,me,might,most,must,my,neither,no,nor,not,of,off,often,on,only,or,other,our,own,rather,said,say,says,she,should,since,so,some,than,that,the,their,them,then,there,these,they,this,tis,to,too,twas,us,wants,was,we,were,what,when,where,which,while,who,whom,why,will,with,would,yet,you,your,use,used'.split(',')

  # Class-level mutex used by the CRAWL_INDEX_ROUTE background job (see config/initializers/girl_friday.rb) to keep multiple jobs from running concurrently
  @index_mutex = Mutex.new

  class << self
    attr_reader :index_mutex
  end

  # Create an instance of the lingua/stemmer class, which is provided by the ruby-stemmer gem: https://github.com/aurelian/ruby-stemmer.
  # this gem provides a ruby api wrapper for the libstemmer_c (Snowball) library: http://snowball.tartarus.org/
  def initialize
    @stemmer = Lingua::Stemmer.new(:language => 'en')
  end

  # call to index all passed-in documents, primarily exists for back-ground CRAWL_INDEX_ROUTE job to call
  # documents: [Model]
  # calling_resource: Model
  # return: nil
  def index(documents, calling_resource)
    update_dictionary_and_postings(documents, calling_resource)
  end

  # call to generate a term list of a document
  # document: string
  # return: [string]
  def generate_term_list(document)
    document_prep(document)
  end

  # call to generate a raw term frequency list of a document
  # document: string
  # return: {string: integer}
  def generate_term_frequency_list(document)
    prep_document_and_count_terms(document)
  end

  private

  # clean-up and tokenize a document (string), stem the terms, and return the stemmed document as an array of stemmed terms
  # document: string
  # return: [string]
  def document_prep(document)
    # remove punctuation, convert all upper case letters to lower case letters, tokenize (split) into words, and remove stop words
    if document.is_a?(String)
      words =  document.gsub(/[[:punct:]]/, '').downcase.split.select { |word| !STOP_WORDS.include?(word) }
      # remove any non-alpha characters in each word and use Porter's stemming algorithm to stem the words, and store them as symbols
      words.map! do |unstemmed_word|
        @stemmer.stem(unstemmed_word.gsub(/[^[[:alpha:]]]/, ''))
      end

      words
    end
  end

  # document: string
  # return: {string: integer}
  def prep_document_and_count_terms(document)
    # initialize an empty hash to hold all the terms and term frequencies in this document: {:hello=>4,:there=>1}
  	words_in_this_document = {}

    # prep the words in the document
    document_prep(document).each do |word|
      # count the number of times a word appears in this document by iterating over the words array
      # and either adding the word to the hash and setting the word count to 1, or incrementing the word count
      # for an existing word by 1. for the document "hello there hello hello hello"
      # the words_in_this_document hash has the final form {:hello=>4,:there=>1}
      words_in_this_document[word] = words_in_this_document.has_key?(word) ? words_in_this_document[word] + 1 : 1
    end

    words_in_this_document
  end

  # documents: [Model]
  # calling_resource: Model
  def update_dictionary_and_postings(documents, calling_resource)
  	# this hash will hold the processed documents during processing. this will be used to store the index to disk
    # once all documents are processed. The reason for doing this (as opposed to writing each document's index data to disk after each document is processed)
    # is to prevent the db connection from being open for potentially long periods of time while documents are being processed.
    processed_documents = {}

  	# for each document in the passed-in documents collection, do the following:
    documents.each do |document|
      words_in_this_document = prep_document_and_count_terms(document.body)

      # add all the word=>word_count entries in this document's hash to the processed_documents hash for use below
      processed_documents[document.id] = words_in_this_document
    end

    # get a db connection, and get references to the dictionary and postings collections
    begin
      db = MongoClient.get_connection
      dictionary = db["#{calling_resource}_dictionary"]
      postings = db["#{calling_resource}_postings"]
    rescue Exception => e
      Rails.logger.error "Error getting mongo connection and/or collections: #{e.inspect}"
    end

    # loop over all the processed documents and save the stats to the dictionary and postings lists
    processed_documents.each do |document_id, words_in_this_document|
      begin
        # for each word=>word_count pair in the words_in_this_document hash, store the stats to the db
        words_in_this_document.each do |word, tf|
          begin
            # try to fetch the dictionary entry for this word from the db
            dictionary_entry = dictionary.find_one(word: word)
            if dictionary_entry # a dictionary entry exists for this word, so increment it's df by 1 and store back to the dictionary
              df = dictionary_entry['df'] + 1
              dictionary.update({_id: dictionary_entry['_id']}, {'$set' => {df: df}})
              dictionary_id = dictionary_entry['_id']
            else # no dictionary entry exists for this word, so create a new entry for the word with df = 1 (since this is the 1st doc the word has appeared in)
              df = 1
              dictionary_id = dictionary.insert({word: word, df: df})
            end

            postings_list = postings.find_one({word_id: dictionary_id})
            if postings_list # there's a postings list for this word already, so just add this posting to it to record the tf for this term for this document
              postings.update({_id: postings_list['_id']}, {'$push' => {postings: {document_id: document_id, tf: tf}}})
            else # no postings list for this word, so create a new list using the word's id, and adding as first posting record the tf for this term for this document
              postings.insert({word_id: dictionary_id, postings: [{document_id: document_id, tf: tf}]})
            end
          rescue Exception => e
            Rails.logger.error "Error updating dictionary and postings for word #{word}: #{e.inspect}"
            next
          end
        end

          # we're done indexing this document, so mark it as indexed and store its euclidean length in the Article record in the db
          document_to_update = calling_resource.where(id: document_id).first
          document_to_update.euclidean_length = Scorer.euclidean_length(words_in_this_document)
          document_to_update.indexed = true
          document_to_update.save
      rescue Exception => e
        Rails.logger.error "Error indexing document #{document_id} to mongo: #{e.inspect}"
        next
      end
    end

    nil
  end
end
# Include in any model that should be able to be indexed
# Any Model used in calls to these methods must include Indexable
# For this to work, any model in which this module is included must have 2 fields:
# indexed (type :boolean)
# euclidean_length (type: float)

module Indexable
  extend ActiveSupport::Concern

  included do
    scope :unindexed, where(indexed: false)

    # generate the term list for the including Model
    def generate_term_list
      Indexer.instance.generate_term_list(self.body)
    end

    # score including Model against a query
    # query_instance: Model
    def score_against(query_instance)
      s = Scorer.instance
      s.score_one(self, query_instance)
    end
  end

  module ClassMethods

    # index all unindexed members of the this Model class's collection
    def index_new
      i = Indexer.instance
      i.index(unindexed, self)
    end

    # score all members of this Model class's collection against a query
    # query_instance: Model
    def score_all_against(query_instance)
      s = Scorer.instance
      s.score_all(self, query_instance)
    end
  end
end
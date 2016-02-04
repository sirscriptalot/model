require 'hanami/utils/class_attribute'
require 'hanami/model/adapters/null_adapter'

module Hanami
  # Mediates between the entities and the persistence layer, by offering an API
  # to query and execute commands on a database.
  #
  #
  #
  # By default, a repository is named after an entity, by appending the
  # `Repository` suffix to the entity class name.
  #
  # @example
  #   require 'hanami/model'
  #
  #   class Article
  #     include Hanami::Entity
  #   end
  #
  #   # valid
  #   class ArticleRepository
  #     include Hanami::Repository
  #   end
  #
  #   # not valid for Article
  #   class PostRepository
  #     include Hanami::Repository
  #   end
  #
  # Repository for an entity can be configured by setting # the `#repository`
  # on the mapper.
  #
  # @example
  #   # PostRepository is repository for Article
  #   mapper = Hanami::Model::Mapper.new do
  #     collection :articles do
  #       entity Article
  #       repository PostRepository
  #     end
  #   end
  #
  # A repository is storage independent.
  # All the queries and commands are delegated to the current adapter.
  #
  # This architecture has several advantages:
  #
  #   * Applications depend on an abstract API, instead of low level details
  #     (Dependency Inversion principle)
  #
  #   * Applications depend on a stable API, that doesn't change if the
  #     storage changes
  #
  #   * Developers can postpone storage decisions
  #
  #   * Isolates the persistence logic at a low level
  #
  # Hanami::Model is shipped with two adapters:
  #
  #   * SqlAdapter
  #   * MemoryAdapter
  #
  #
  #
  # All the queries and commands are private.
  # This decision forces developers to define intention revealing API, instead
  # leak storage API details outside of a repository.
  #
  # @example
  #   require 'hanami/model'
  #
  #   # This is bad for several reasons:
  #   #
  #   #  * The caller has an intimate knowledge of the internal mechanisms
  #   #      of the Repository.
  #   #
  #   #  * The caller works on several levels of abstraction.
  #   #
  #   #  * It doesn't express a clear intent, it's just a chain of methods.
  #   #
  #   #  * The caller can't be easily tested in isolation.
  #   #
  #   #  * If we change the storage, we are forced to change the code of the
  #   #    caller(s).
  #
  #   ArticleRepository.where(author_id: 23).order(:published_at).limit(8)
  #
  #
  #
  #   # This is a huge improvement:
  #   #
  #   #  * The caller doesn't know how the repository fetches the entities.
  #   #
  #   #  * The caller works on a single level of abstraction.
  #   #    It doesn't even know about records, only works with entities.
  #   #
  #   #  * It expresses a clear intent.
  #   #
  #   #  * The caller can be easily tested in isolation.
  #   #    It's just a matter of stub this method.
  #   #
  #   #  * If we change the storage, the callers aren't affected.
  #
  #   ArticleRepository.most_recent_by_author(author)
  #
  #   class ArticleRepository
  #     include Hanami::Repository
  #
  #     def self.most_recent_by_author(author, limit = 8)
  #       query do
  #         where(author_id: author.id).
  #           order(:published_at)
  #       end.limit(limit)
  #     end
  #   end
  #
  # @since 0.1.0
  #
  # @see Hanami::Entity
  # @see http://martinfowler.com/eaaCatalog/repository.html
  # @see http://en.wikipedia.org/wiki/Dependency_inversion_principle
  module Repository
    # Inject the public API into the hosting class.
    #
    # @since 0.1.0
    #
    # @example
    #   require 'hanami/model'
    #
    #   class UserRepository
    #     include Hanami::Repository
    #   end
    def self.included(base)
      base.class_eval do
        extend ClassMethods
        include Hanami::Utils::ClassAttribute

        class_attribute :collection
        self.adapter = Hanami::Model::Adapters::NullAdapter.new
      end
    end

    module ClassMethods
      # Assigns an adapter.
      #
      # Hanami::Model is shipped with two adapters:
      #
      #   * SqlAdapter
      #   * MemoryAdapter
      #
      # @param adapter [Object] an object that implements
      #   `Hanami::Model::Adapters::Abstract` interface
      #
      # @since 0.1.0
      #
      # @see Hanami::Model::Adapters::SqlAdapter
      # @see Hanami::Model::Adapters::MemoryAdapter
      #
      # @example Memory adapter
      #   require 'hanami/model'
      #   require 'hanami/model/adapters/memory_adapter'
      #
      #   mapper = Hanami::Model::Mapper.new do
      #     # ...
      #   end
      #
      #   adapter = Hanami::Model::Adapters::MemoryAdapter.new(mapper)
      #
      #   class UserRepository
      #     include Hanami::Repository
      #   end
      #
      #   UserRepository.adapter = adapter
      #
      #
      #
      # @example SQL adapter with a Sqlite database
      #   require 'sqlite3'
      #   require 'hanami/model'
      #   require 'hanami/model/adapters/sql_adapter'
      #
      #   mapper = Hanami::Model::Mapper.new do
      #     # ...
      #   end
      #
      #   adapter = Hanami::Model::Adapters::SqlAdapter.new(mapper, 'sqlite://path/to/database.db')
      #
      #   class UserRepository
      #     include Hanami::Repository
      #   end
      #
      #   UserRepository.adapter = adapter
      #
      #
      #
      # @example SQL adapter with a Postgres database
      #   require 'pg'
      #   require 'hanami/model'
      #   require 'hanami/model/adapters/sql_adapter'
      #
      #   mapper = Hanami::Model::Mapper.new do
      #     # ...
      #   end
      #
      #   adapter = Hanami::Model::Adapters::SqlAdapter.new(mapper, 'postgres://host:port/database')
      #
      #   class UserRepository
      #     include Hanami::Repository
      #   end
      #
      #   UserRepository.adapter = adapter
      def adapter=(adapter)
        @adapter = adapter
      end

      # @since 0.5.0
      # @api private
      def adapter
        @adapter
      end

      # Creates or updates a record in the database for the given entity.
      #
      # @param entity [#id, #id=] the entity to persist
      #
      # @return [Object] a copy of the entity with `id` assigned
      #
      # @since 0.1.0
      #
      # @see Hanami::Repository#create
      # @see Hanami::Repository#update
      #
      # @example With a non persisted entity
      #   require 'hanami/model'
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #   end
      #
      #   article = Article.new(title: 'Introducing Hanami::Model')
      #   article.id # => nil
      #
      #   persisted_article = ArticleRepository.persist(article) # creates a record
      #   article.id # => nil
      #   persisted_article.id # => 23
      #
      # @example With a persisted entity
      #   require 'hanami/model'
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #   end
      #
      #   article = ArticleRepository.find(23)
      #   article.id # => 23
      #
      #   article.title = 'Launching Hanami::Model'
      #   ArticleRepository.persist(article) # updates the record
      #
      #   article = ArticleRepository.find(23)
      #   article.title # => "Launching Hanami::Model"
      def persist(entity)
        _touch(entity)
        @adapter.persist(collection, entity)
      end

      # Creates a record in the database for the given entity.
      # It returns a copy of the entity with `id` assigned.
      #
      # If already persisted (`id` present) it does nothing.
      #
      # @param entity [#id,#id=] the entity to create
      #
      # @return [Object] a copy of the entity with `id` assigned
      #
      # @since 0.1.0
      #
      # @see Hanami::Repository#persist
      #
      # @example
      #   require 'hanami/model'
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #   end
      #
      #   article = Article.new(title: 'Introducing Hanami::Model')
      #   article.id # => nil
      #
      #   created_article = ArticleRepository.create(article) # creates a record
      #   article.id # => nil
      #   created_article.id # => 23
      #
      #   created_article = ArticleRepository.create(article)
      #   created_article.id # => 24
      #
      #   created_article = ArticleRepository.create(existing_article) # => no-op
      #   created_article # => nil
      #
      def create(entity)
        unless _persisted?(entity)
          _touch(entity)
          @adapter.create(collection, entity)
        end
      end

      # Updates a record in the database corresponding to the given entity.
      #
      # If not already persisted (`id` present) it raises an exception.
      #
      # @param entity [#id] the entity to update
      #
      # @return [Object] the entity
      #
      # @raise [Hanami::Model::NonPersistedEntityError] if the given entity
      #   wasn't already persisted.
      #
      # @since 0.1.0
      #
      # @see Hanami::Repository#persist
      # @see Hanami::Model::NonPersistedEntityError
      #
      # @example With a persisted entity
      #   require 'hanami/model'
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #   end
      #
      #   article = ArticleRepository.find(23)
      #   article.id # => 23
      #   article.title = 'Launching Hanami::Model'
      #
      #   ArticleRepository.update(article) # updates the record
      #
      #
      #
      # @example With a non persisted entity
      #   require 'hanami/model'
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #   end
      #
      #   article = Article.new(title: 'Introducing Hanami::Model')
      #   article.id # => nil
      #
      #   ArticleRepository.update(article) # raises Hanami::Model::NonPersistedEntityError
      def update(entity)
        if _persisted?(entity)
          _touch(entity)
          @adapter.update(collection, entity)
        else
          raise Hanami::Model::NonPersistedEntityError
        end
      end

      # Deletes a record in the database corresponding to the given entity.
      #
      # If not already persisted (`id` present) it raises an exception.
      #
      # @param entity [#id] the entity to delete
      #
      # @return [Object] the entity
      #
      # @raise [Hanami::Model::NonPersistedEntityError] if the given entity
      #   wasn't already persisted.
      #
      # @since 0.1.0
      #
      # @see Hanami::Model::NonPersistedEntityError
      #
      # @example With a persisted entity
      #   require 'hanami/model'
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #   end
      #
      #   article = ArticleRepository.find(23)
      #   article.id # => 23
      #
      #   ArticleRepository.delete(article) # deletes the record
      #
      #
      #
      # @example With a non persisted entity
      #   require 'hanami/model'
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #   end
      #
      #   article = Article.new(title: 'Introducing Hanami::Model')
      #   article.id # => nil
      #
      #   ArticleRepository.delete(article) # raises Hanami::Model::NonPersistedEntityError
      def delete(entity)
        if _persisted?(entity)
          @adapter.delete(collection, entity)
        else
          raise Hanami::Model::NonPersistedEntityError
        end

        entity
      end

      # Returns all the persisted entities.
      #
      # @return [Array<Object>] the result of the query
      #
      # @since 0.1.0
      #
      # @example
      #   require 'hanami/model'
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #   end
      #
      #   ArticleRepository.all # => [ #<Article:0x007f9b19a60098> ]
      def all
        @adapter.all(collection)
      end

      # Finds an entity by its identity.
      #
      # If used with a SQL database, it corresponds to the primary key.
      #
      # @param id [Object] the identity of the entity
      #
      # @return [Object,NilClass] the result of the query, if present
      #
      # @since 0.1.0
      #
      # @example
      #   require 'hanami/model'
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #   end
      #
      #   ArticleRepository.find(23)   # => #<Article:0x007f9b19a60098>
      #   ArticleRepository.find(9999) # => nil
      def find(id)
        @adapter.find(collection, id)
      end

      # Returns the first entity in the database.
      #
      # @return [Object,nil] the result of the query
      #
      # @since 0.1.0
      #
      # @see Hanami::Repository#last
      #
      # @example With at least one persisted entity
      #   require 'hanami/model'
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #   end
      #
      #   ArticleRepository.first # => #<Article:0x007f8c71d98a28>
      #
      # @example With an empty collection
      #   require 'hanami/model'
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #   end
      #
      #   ArticleRepository.first # => nil
      def first
        @adapter.first(collection)
      end

      # Returns the last entity in the database.
      #
      # @return [Object,nil] the result of the query
      #
      # @since 0.1.0
      #
      # @see Hanami::Repository#last
      #
      # @example With at least one persisted entity
      #   require 'hanami/model'
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #   end
      #
      #   ArticleRepository.last # => #<Article:0x007f8c71d98a28>
      #
      # @example With an empty collection
      #   require 'hanami/model'
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #   end
      #
      #   ArticleRepository.last # => nil
      def last
        @adapter.last(collection)
      end

      # Deletes all the records from the current collection.
      #
      # If used with a SQL database it executes a `DELETE FROM <table>`.
      #
      # @since 0.1.0
      #
      # @example
      #   require 'hanami/model'
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #   end
      #
      #   ArticleRepository.clear # deletes all the records
      def clear
        @adapter.clear(collection)
      end

      # Wraps the given block in a transaction.
      #
      # For performance reasons the block isn't in the signature of the method,
      # but it's yielded at the lower level.
      #
      # Please note that it's only supported by some databases.
      # For this reason, the accepted options may be different from adapter to
      # adapter.
      #
      # For advanced scenarios, please check the documentation of each adapter.
      #
      # @param options [Hash] options for transaction
      #
      # @see Hanami::Model::Adapters::SqlAdapter#transaction
      # @see Hanami::Model::Adapters::MemoryAdapter#transaction
      #
      # @since 0.2.3
      #
      # @example Basic usage with SQL adapter
      #   require 'hanami/model'
      #
      #   class Article
      #     include Hanami::Entity
      #     attributes :title, :body
      #   end
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #   end
      #
      #   article = Article.new(title: 'Introducing transactions',
      #     body: 'lorem ipsum')
      #
      #   ArticleRepository.transaction do
      #     ArticleRepository.dangerous_operation!(article) # => RuntimeError
      #     # !!! ROLLBACK !!!
      #   end
      def transaction(options = {})
        @adapter.transaction(options) do
          yield
        end
      end

      private

      # Executes the given raw statement on the adapter.
      #
      # Please note that it's only supported by some databases,
      # a `NotImplementedError` will be raised when the adapter does not
      # responds to the `execute` method.
      #
      # For advanced scenarios, please check the documentation of each adapter.
      #
      # @param raw [String] the raw statement to execute on the connection
      #
      # @return [NilClass]
      #
      # @raise [NotImplementedError] if current Hanami::Model adapter doesn't
      #   implement `execute`.
      #
      # @raise [Hanami::Model::InvalidCommandError] if the raw statement is invalid
      #
      # @see Hanami::Model::Adapters::Abstract#execute
      # @see Hanami::Model::Adapters::SqlAdapter#execute
      #
      # @since 0.3.1
      #
      # @example Basic usage with SQL adapter
      #   require 'hanami/model'
      #
      #   class Article
      #     include Hanami::Entity
      #     attributes :title, :body
      #   end
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #
      #     def self.reset_comments_count
      #       execute "UPDATE articles SET comments_count = 0"
      #     end
      #   end
      #
      #   ArticleRepository.reset_comments_count
      def execute(raw)
        @adapter.execute(raw)
      end

      # Fetch raw result sets for the the given statement.
      #
      # PLEASE NOTE: The returned result set contains an array of hashes.
      #              The columns are returned as they are from the database,
      #              the mapper is bypassed here.
      #
      # @param raw [String] the raw statement used to fetch records
      # @param blk [Proc] an optional block that is yielded for each record
      #
      # @return [Enumerable<Hash>,Array<Hash>] the collection of raw records
      #
      # @raise [NotImplementedError] if current Hanami::Model adapter doesn't
      #   implement `fetch`.
      #
      # @raise [Hanami::Model::InvalidQueryError] if the raw statement is invalid
      #
      # @since 0.5.0
      #
      # @example Basic Usage
      #   require 'hanami/model'
      #
      #   mapping do
      #     collection :articles do
      #       attribute :id,    Integer, as: :s_id
      #       attribute :title, String,  as: :s_title
      #     end
      #   end
      #
      #   class Article
      #     include Hanami::Entity
      #     attributes :title, :body
      #   end
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #
      #     def self.all_raw
      #       fetch("SELECT * FROM articles")
      #     end
      #   end
      #
      #   ArticleRepository.all_raw
      #     # => [{:_id=>1, :user_id=>nil, :s_title=>"Art 1", :comments_count=>nil, :umapped_column=>nil}]
      #
      # @example Map A Value From Result Set
      #   require 'hanami/model'
      #
      #   mapping do
      #     collection :articles do
      #       attribute :id,    Integer, as: :s_id
      #       attribute :title, String,  as: :s_title
      #     end
      #   end
      #
      #   class Article
      #     include Hanami::Entity
      #     attributes :title, :body
      #   end
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #
      #     def self.titles
      #       fetch("SELECT s_title FROM articles").map do |article|
      #         article[:s_title]
      #       end
      #     end
      #   end
      #
      #   ArticleRepository.titles # => ["Announcing Hanami v0.5.0"]
      #
      # @example Passing A Block
      #   require 'hanami/model'
      #
      #   mapping do
      #     collection :articles do
      #       attribute :id,    Integer, as: :s_id
      #       attribute :title, String,  as: :s_title
      #     end
      #   end
      #
      #   class Article
      #     include Hanami::Entity
      #     attributes :title, :body
      #   end
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #
      #     def self.titles
      #       result = []
      #
      #       fetch("SELECT s_title FROM articles") do |article|
      #         result << article[:s_title]
      #       end
      #
      #       result
      #     end
      #   end
      #
      #   ArticleRepository.titles # => ["Announcing Hanami v0.5.0"]
      def fetch(raw, &blk)
        @adapter.fetch(raw, &blk)
      end

      # Fabricates a query and yields the given block to access the low level
      # APIs exposed by the query itself.
      #
      # This is a Ruby private method, because we wanted to prevent outside
      # objects to query directly the database. However, this is a public API
      # method, and this is the only way to filter entities.
      #
      # The returned query SHOULD be lazy: the entities should be fetched by
      # the database only when needed.
      #
      # The returned query SHOULD refer to the entire collection by default.
      #
      # Queries can be reused and combined together. See the example below.
      # IMPORTANT: This feature works only with the Sql adapter.
      #
      # A repository is storage independent.
      # All the queries are delegated to the current adapter, which is
      # responsible to implement a querying API.
      #
      # Hanami::Model is shipped with two adapters:
      #
      #   * SqlAdapter, which yields a Hanami::Model::Adapters::Sql::Query
      #   * MemoryAdapter, which yields a Hanami::Model::Adapters::Memory::Query
      #
      # @param blk [Proc] a block of code that is executed in the context of a
      #   query
      #
      # @return a query, the type depends on the current adapter
      #
      # @api public
      # @since 0.1.0
      #
      # @see Hanami::Model::Adapters::Sql::Query
      # @see Hanami::Model::Adapters::Memory::Query
      #
      # @example
      #   require 'hanami/model'
      #
      #   class ArticleRepository
      #     include Hanami::Repository
      #
      #     def self.most_recent_by_author(author, limit = 8)
      #       query do
      #         where(author_id: author.id).
      #           desc(:published_at).
      #           limit(limit)
      #       end
      #     end
      #
      #     def self.most_recent_published_by_author(author, limit = 8)
      #       # combine .most_recent_published_by_author and .published queries
      #       most_recent_by_author(author, limit).published
      #     end
      #
      #     def self.published
      #       query do
      #         where(published: true)
      #       end
      #     end
      #
      #     def self.rank
      #       # reuse .published, which returns a query that respond to #desc
      #       published.desc(:comments_count)
      #     end
      #
      #     def self.best_article_ever
      #       # reuse .published, which returns a query that respond to #limit
      #       rank.limit(1)
      #     end
      #
      #     def self.comments_average
      #       query.average(:comments_count)
      #     end
      #   end
      def query(&blk)
        @adapter.query(collection, self, &blk)
      end

      # Negates the filtering conditions of a given query with the logical
      # opposite operator.
      #
      # This is only supported by the SqlAdapter.
      #
      # @param query [Object] a query
      #
      # @return a negated query, the type depends on the current adapter
      #
      # @api public
      # @since 0.1.0
      #
      # @see Hanami::Model::Adapters::Sql::Query#negate!
      #
      # @example
      #   require 'hanami/model'
      #
      #   class ProjectRepository
      #     include Hanami::Repository
      #
      #     def self.cool
      #       query do
      #         where(language: 'ruby')
      #       end
      #     end
      #
      #     def self.not_cool
      #       exclude cool
      #     end
      #   end
      def exclude(query)
        query.negate!
        query
      end

      # This is a method to check entity persited or not
      #
      # @param entity
      # @return a boolean value
      # @since 0.3.1
      def _persisted?(entity)
        !!entity.id
      end

      # Update timestamps
      #
      # @param entity [Object, Hanami::Entity] the entity
      #
      # @api private
      # @since 0.3.1
      def _touch(entity)
        now = Time.now.utc

        if _has_timestamp?(entity, :created_at)
          entity.created_at ||= now
        end

        if _has_timestamp?(entity, :updated_at)
          entity.updated_at = now
        end
      end

      # Check if the given entity has the given timestamp
      #
      # @param entity [Object, Hanami::Entity] the entity
      # @param timestamp [Symbol] the timestamp name
      #
      # @return [TrueClass,FalseClass]
      #
      # @api private
      # @since 0.3.1
      def _has_timestamp?(entity, timestamp)
        entity.respond_to?(timestamp) &&
          entity.respond_to?("#{ timestamp }=")
      end
    end
  end
end
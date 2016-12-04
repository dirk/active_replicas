# ActiveReplicas

Drop-in read-replica querying in ActiveRecord. It proxies around ActiveRecord's connection to send read-only queries to replica databases; writes will automatically go to the primary and "stick" the request into using the primary for any further queries.

This is heavily inspired by [Kickstarter's `replica_pools`](https://github.com/kickstarter/replica_pools) gem. It seeks to improve on that gem by better interfacing with ActiveRecord's connection pools.

## Installation & usage

ActiveReplicas injects itself into ActiveRecord. To start you'll want to add it to your application's `Gemfile`:

```ruby
gem 'active_replicas'
```

You then need to instruct it as to which connection to use for the primary and which connection(s) to use for the read replicas:

```ruby
# config/initializers/active_replicas.rb
ActiveReplicas::Railtie.hijack_active_record primary: { url: 'mysql2://user@primary/my_app' },
                                             replicas: {
                                               replica0: { url: 'mysql2://user@replica/my_app' }
                                             }
```

**Note**: ActiveReplicas does not do anything automatically. It only injects itself into ActiveRecord when you tell it do so (see above).

## How it works

A few things happen when you call `hijack_active_record`:

- It defines delegations for the [connection][] methods that can be sent to replicas and the methods that must be sent to a primary.
- It sets up a `ConnectionHandler` that will act in place of ActiveRecord's normal `ConnectionHandler`.
- It takes over the usual ActiveRecord `LogSubscriber` to add information about replica/primary status to logging messages.

[connection]: http://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters.html

## Contributing

Bug reports and pull requests are welcome on [GitHub][]. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

[GitHub]: https://github.com/dirk/active_replicas

## License

Licensed under the 3-clause BSD license. See [LICENSE](LICENSE) for details.

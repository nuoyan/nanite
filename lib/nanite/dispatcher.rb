module Nanite
  class Dispatcher
    attr_reader :amq, :registry, :serializer, :identity, :log

    def initialize(amq, registry, serializer, identity, log)
      @amq = amq
      @registry = registry
      @serializer = serializer
      @identity = identity
      @log = log
    end

    def dispatch(request)
      result = begin
        act_upon(request)
      rescue Exception => e
        error = "#{e.class.name}: #{e.message}\n  #{e.backtrace.join("\n  ")}"
        log.error(error)
        error
      end

      if request.reply_to
        packet = Result.new(request.token, request.reply_to, result, identity)
        # TODO, persist?
        amq.queue(request.reply_to, :no_declare => true).publish(serializer.dump(packet))
      end
    end

    private

    def act_upon(request)
      prefix, meth = request.type.split('/')[1..-1]
      actor = registry.actor_for(prefix)
      actor.send(meth || 'index', request.payload)
    end
  end
end
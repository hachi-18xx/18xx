# frozen_string_literal: true

require_relative '../stock'

module Engine
  module Round
    module G1824
      class FirstStock < Stock
        attr_reader :reverse

        def description
          'First Stock Round'
        end

        def setup
          @reverse = true

          super

          @entities.reverse!
        end

        def select_entities
          @game.players.reverse
        end

        def next_entity_index!
          if @entity_index == @game.players.size - 1
            @reverse = false
            @entities = @game.players
          end
          return super unless @reverse

          @entity_index = (@entity_index - 1) % @entities.size
        end

        def finish_round
          # It is possible a regional has been sold out - handle stock movement for that
          @game.corporations.select { |c| @game.regional?(c) && c.floated? }.sort.each do |corp|
            prev = corp.share_price.price
            sold_out_stock_movement(corp) if sold_out?(corp)
            @game.log_share_price(corp, prev)
          end

          @game.log << 'First stock round is finished - any unsold Pre-State Railways, Coal Railways, ' \
            ' and Montain Railways are removed from the game'

          @game.companies.each do |c|
            next if c.owner || c.closed?

            if @game.mountain_railway?(c)
              @game.log << "Mountain Railway #{c.name} closes"
              c.close!
              next
            end

            # Private is a control of a pre-staatsbahn
            pre_state = @game.minor_by_id(c.id)
            state = @game.associated_state_railway(c)
            @game.log << "Pre-Staatsbahn Railway #{pre_state.name} closes; "\
              "corresponding share in #{state.name} is no longer reserved"

            # Remove home token
            pre_state.tokens.first.remove!

            close_corporation(pre_state)

            c.close!
          end

          @game.corporations.select { |c| @game.coal_railway?(c) }.each do |c|
            next if c.floated?

            regional = @game.associated_regional_railway(c)
            @game.log << "#{c.name} closes; #{regional.name}'s presidency share is no longer reserved"

            close_corporation(c)

            # Make reserved share of associated corporation unreserved
            regional.shares.find(&:president).buyable = true
            regional.floatable = true
            @game.abilities(regional, :base) do |ability|
              regional.remove_ability(ability)
            end
          end
        end

        private

        def close_corporation(corporation)
          # Remove home city reservation
          remove_reservation(corporation)

          corporation.close!
          corporation.removed = true
        end

        def remove_reservation(corporation)
          hex = @game.hex_by_id(corporation.coordinates)
          tile = hex.tile
          cities = tile.cities
          city = cities.find { |c| c.reserved_by?(corporation) } || cities.first
          city.remove_reservation!(corporation)
        end
      end
    end
  end
end

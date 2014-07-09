require "active_model/errors"
require "hotel_beds/model/hotel"

module HotelBeds
  module HotelSearch
    class Response
      attr_accessor :headers, :body, :errors
      private :headers=, :body=, :errors=
      
      def initialize(response)
        self.headers = response.header
        self.body = Nokogiri::XML(response.body.fetch(:get_hotel_valued_avail))
        self.errors = ActiveModel::Errors.new(self).tap do |errors|
          if response.http_error?
            errors.add(:base, "HTTP error")
          elsif response.soap_fault?
            errors.add(:base, "SOAP error")
          elsif !response.success?
            errors.add(:base, "Request failed")
          end
        end
        freeze
      end
      
      def inspect
        "<#{self.class.name} headers=#{headers.inspect} body=#{body.inspect}>"
      end
      
      def current_page
        Integer(body.css("PaginationData").first.attr("currentPage"))
      end
      
      def total_pages
        Integer(body.css("PaginationData").first.attr("totalPages"))
      end
      
      def hotels
        body.css("ServiceHotel").lazy.map do |hotel|
          HotelBeds::Model::Hotel.new({
            id: hotel.css("HotelInfo Code").first.content,
            name: hotel.css("HotelInfo Name").first.content,
            images: hotel.css("HotelInfo ImageList Image Url").map(&:content),
            latitude: hotel.css("HotelInfo Position").first.attr("latitude"),
            longitude: hotel.css("HotelInfo Position").first.attr("longitude"),
            results: hotel.css("AvailableRoom").map { |result|
              {
                adult_count: result.css("HotelOccupancy AdultCount").first.content,
                child_count: result.css("HotelOccupancy ChildCount").first.content,
                rooms: result.css("HotelRoom").map { |room|
                  {
                    number_available: room.attr("availCount"),
                    id: room.attr("SHRUI"),
                    description: room.css("RoomType").first.content,
                    board: room.css("Board").first.content,
                    price: room.css("Price Amount").first.content,
                    currency: body.css("Currency").first.attribute("code").value
                  }
                }
              }
            }
          })
        end
      end
    end
  end
end

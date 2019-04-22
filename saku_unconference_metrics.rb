require "excon"
require "json"

def connection
  @connection ||= Excon.new(
    "https://api.trello.com"
  )
end

def request(path, query = {})
  query = {
    key: ENV["TRELLO_KEY"],
    token: ENV["TRELLO_TOKEN"]
  }.merge(query)
  JSON.parse(connection.get(path: path, query: query).body)
end

puts "Saku Unconference"

board_id = "li4drZV3"

members = request("/1/boards/#{board_id}/members").map {|member| member["username"]}
puts "#{members.count} board members"

#puts request("/1/boards/#{board_id}/lists/")
proposed_list_id = "5cb4dbd8de0fab5eb5bdbca1"
proposed_cards = request("/1/lists/#{proposed_list_id}/cards")

authors = []
board_actions = request(
    "/1/boards/#{board_id}/actions",
    {
      filter: ["copyCard", "createCard"]
    }
  )
board_actions.each do |action|
  authors << action["memberCreator"]["username"]
end
authors.uniq!

voters = []
proposed_cards.each do |card|
  voters.append(*card['idMembersVoted'])
end

participants_count = (authors + voters).uniq.count
participation = ((participants_count.to_f / 285).to_f * 100).round

puts "#{Time.now.utc.strftime('%a %b %e %k:%M')} = #{participation}% participation: #{proposed_cards.count} topics, #{voters.count} votes, #{participants_count} participants"

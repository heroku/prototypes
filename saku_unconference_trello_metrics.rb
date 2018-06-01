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

board_id = "ZTunu3ww"

members = request("/1/boards/#{board_id}/members").map {|member| member["username"]}
puts "#{members.count} board members"

#puts request("/1/boards/#{board_id}/lists/")
proposed_list_id = "5afb4079653494f2284768e3"
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
puts "#{proposed_cards.count} sessions from #{authors.count} authors"

voters = []
proposed_cards.each do |card|
  voters.append(*card['idMembersVoted'])
end
puts "#{voters.count} votes from #{voters.uniq.count} voters"

puts "#{Time.now}"

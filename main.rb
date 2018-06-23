require 'json'
require 'byebug'
data = JSON.parse(File.open('data.json').read)

queued_orders = data['queued_orders'].group_by do |order|
  order['direction']
end

sell_orders = queued_orders['sell'].group_by do |sell_order|
  sell_order['price']
end


def self.execute_order(buy, sell, price, users)
  baught_amount = [buy['btc_amount'], sell['btc_amount']].min
  
  # update user balance
  users[buy['user_id']]['eur_balance'] -= baught_amount * price
  users[buy['user_id']]['btc_balance'] += baught_amount
  users[sell['user_id']]['eur_balance'] += baught_amount * price
  users[sell['user_id']]['btc_balance'] -= baught_amount

  # update current orders
  buy['btc_amount'] -= baught_amount
  sell['btc_amount'] -= baught_amount

  executed_orders = [buy.dup, sell.dup].map do |order|
    order.merge({
      'btc_amount' => baught_amount,
      'state' => 'executed'  
    })
  end
end

users = {}
data['users'].each do |user|
  users[user['id']] = user
end

executed_orders = []
indexes_to_delete = []
queued_orders['buy'].each_with_index do |buy_order, index|
  while buy_order['btc_amount'] != 0
    sell_order = sell_orders[buy_order['price']].pop
    break if !sell_order
    executed_orders += execute_order(
      buy_order,
      sell_order,
      buy_order['price'],
      users
    )
    if sell_order['btc_amount'] > 0
      sell_orders[buy_order['price']] << sell_order
    end
  end
  if buy_order['btc_amount'] == 0
    indexes_to_delete << index
  end
end

indexes_to_delete.each do |index_to_delete|
  queued_orders['buy'].delete_at(index_to_delete)
end

result = {
  queued_orders: queued_orders['buy'] + sell_orders.values.flatten,
  executed_orders: executed_orders,
  users: users
}

output_file = File.open('output.json', 'w')
output_file.write(JSON.pretty_generate(result))
class CreateConversationsAndChatMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.references :business, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: { to_table: :users }
      t.datetime :last_message_at
      t.timestamps
    end
    add_index :conversations, [ :business_id, :customer_id ], unique: true
    add_index :conversations, :last_message_at

    create_table :chat_messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false
      t.datetime :read_at
      t.timestamps
    end
    add_index :chat_messages, [ :conversation_id, :id ]
    add_index :chat_messages, [ :conversation_id, :read_at ]
  end
end

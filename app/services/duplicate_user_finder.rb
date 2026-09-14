class DuplicateUserFinder
  def self.call(users = User.where(admin: false))
    candidates = users.where.not("name LIKE ?", "% (結合済み)").to_a
    pairs = {}

    group(candidates) { |user| User.phone_matching_key(user.phone_number) }
      .each { |users_in_group| add_pairs(pairs, users_in_group, "電話番号") }
    group(candidates) { |user| user.email.to_s.strip.downcase.presence }
      .each { |users_in_group| add_pairs(pairs, users_in_group, "メール") }
    group(candidates) { |user| user.line_user_id.to_s.strip.presence }
      .each { |users_in_group| add_pairs(pairs, users_in_group, "LINE") }

    pairs.values.sort_by { |candidate| candidate[:users].map(&:id) }
  end

  def self.group(users)
    users.group_by { |user| yield(user) }
         .reject { |key, grouped| key.blank? || grouped.size < 2 }
         .values
  end
  private_class_method :group

  def self.add_pairs(pairs, users, reason)
    users.combination(2) do |left, right|
      key = [left.id, right.id].sort
      pairs[key] ||= { users: [left, right].sort_by(&:id), reasons: [] }
      pairs[key][:reasons] << reason unless pairs[key][:reasons].include?(reason)
    end
  end
  private_class_method :add_pairs
end

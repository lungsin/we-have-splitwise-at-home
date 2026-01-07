#include <algorithm>
#include <cassert>
#include <iostream>
#include <map>
#include <random>
#include <sstream>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

struct Transaction {
  int from, to;
  long long value;
};

std::vector<Transaction> solve(std::vector<long long> const &net) {
  assert(std::accumulate(net.begin(), net.end(), 0LL) == 0LL);
  std::vector<Transaction> result;

  std::map<long long, std::vector<int>> net_pos, net_neg;
  for (int i = 0; i < net.size(); ++i) {
    auto val = net[i];
    if (val == 0)
      continue;
    if (val < 0)
      net_neg[-val].push_back(i);
    else if (val > 0)
      net_pos[val].push_back(i);
  }

  // This is a heuristic subroutine to match the exact match
  auto check_and_remove_exact_match = [&](int val) -> void {
    auto it_pos = net_pos.find(val);
    auto it_neg = net_neg.find(val);
    if (it_pos == net_pos.end() or it_neg == net_neg.end())
      return;
    auto &ids_pos = it_pos->second;
    auto &ids_neg = it_neg->second;
    while (ids_pos.size() && ids_neg.size()) {
      result.push_back({ids_neg.back(), ids_pos.back(), val});
      ids_pos.pop_back();
      ids_neg.pop_back();
    }
    if (ids_pos.empty())
      net_pos.erase(it_pos);
    if (ids_neg.empty())
      net_neg.erase(it_neg);
  };

  // Remove exact match first
  for (auto val : net)
    if (val > 0)
      check_and_remove_exact_match(val);

  // Greedy algo: match the two with largest value
  while (net_pos.size() && net_neg.size()) {
    auto it_neg = std::prev(net_neg.end());
    auto it_pos = std::prev(net_pos.end());
    auto &val_from = it_neg->first;
    auto &ids_from = it_neg->second;
    auto &val_to = it_pos->first;
    auto &ids_to = it_pos->second;
    auto transaction_val = std::min(val_from, val_to);
    int transaction_count = std::min(ids_from.size(), ids_to.size());
    // Match the largest values
    for (int i = 0; i < transaction_count; ++i) {
      auto id_from = ids_from.back();
      auto id_to = ids_to.back();
      result.push_back({id_from, id_to, transaction_val});
      ids_from.pop_back();
      ids_to.pop_back();
      if (val_from < val_to)
        net_pos[val_to - val_from].push_back(id_to);
      else if (val_to < val_from)
        net_neg[val_from - val_to].push_back(id_from);
    }

    if (ids_from.empty())
      net_neg.erase(it_neg);
    if (ids_to.empty())
      net_pos.erase(it_pos);

    // Check and remove for exact match
    check_and_remove_exact_match(std::abs(val_from - val_to));
  }
  assert(net_pos.empty() && net_neg.empty());

  // a little validation on the result
  std::vector<long long> net_result(net.size(), 0LL);
  for (auto t : result) {
    net_result[t.from] -= t.value;
    net_result[t.to] += t.value;
  }
  assert(net == net_result);

  return result;
}

// Cut the string after the '#' character
std::string ignore_comment(std::string const &s) {
  auto hash_pos = s.find('#');
  if (hash_pos != std::string::npos)
    return s.substr(0, hash_pos);
  return s;
}

int main() {
  // Random stuff
  std::random_device rd;
  std::mt19937 g(rd());

  // Data parsed from the input
  //  - name_to_id: mapping from name to an integer id
  //  - names: the names of the each person
  //  - net: the net money that each person gets once the debt is settled
  std::unordered_map<std::string, int> name_to_id;
  std::vector<std::string> names;
  std::vector<long long> net;

  // A subroutine to register a new name the the data structures above
  // Returns the int id that represents that new name
  auto register_name = [&](std::string const &name) -> int {
    if (not name_to_id.count(name)) {
      int id = names.size();
      names.push_back(name);
      net.push_back(0LL);
      name_to_id[name] = id;
      return id;
    }
    return name_to_id[name];
  };

  // Input parsing routine
  for (std::string s; std::getline(std::cin, s);) {
    s = ignore_comment(s);
    std::stringstream ss(s);
    std::string name;
    std::vector<std::string> froms_str;
    std::vector<int> froms;
    int to = -1;
    long long money = 0;

    while (ss >> name) {
      if (name == "->")
        break;
      froms_str.push_back(name);
    }
    if (froms_str.empty() || name != "->")
      continue;
    double money_float;
    ss >> name >> money_float;
    if (ss.fail())
      continue;
    for (auto from_name : froms_str)
      froms.push_back(register_name(from_name));
    to = register_name(name);

    // Convert the money to 64bit integer with its value rounded down to
    // nearest cent. Operating money with integer is better because we
    // don't have to worry about weird float calculation error.
    money = money_float * 100;

    net[to] += money;
    std::shuffle(froms.begin(), froms.end(), g);
    for (int i = 0; i < froms.size(); ++i) {
      int from = froms[i];
      long long debt = money / froms.size();
      if (i < money - debt * froms.size())
        debt += 1;
      net[from] -= debt;
    }
  }

  // Run the solver to get a good-enough transaction list.
  auto transactions = solve(net);

  // Pretty print the transactions with indentation
  size_t max_from_name_len = 0;
  size_t max_to_name_len = 0;
  int max_value_len = 0;
  for (auto const &t : transactions) {
    max_from_name_len = std::max(max_from_name_len, names[t.from].size());
    max_to_name_len = std::max(max_to_name_len, names[t.to].size());

    auto value = t.value;
    int cnt_digit = 0;
    for (auto value = t.value; value > 0; value /= 10)
      cnt_digit++;
    max_value_len = std::max(max_value_len, cnt_digit);
  }
  for (auto const &t : transactions) {
    printf("%*s -> %-*s : %*.2lf\n", (int)max_from_name_len,
           names[t.from].c_str(), (int)max_to_name_len, names[t.to].c_str(),
           max_value_len, (double)t.value / 100.0);
  }

  return 0;
}

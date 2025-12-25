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
    else
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
      result.push_back({ids_from.back(), ids_to.back(), transaction_val});
      ids_from.pop_back();
      ids_to.pop_back();
      if (val_from < val_to)
        net_pos[val_to - val_from].push_back(ids_to.back());
      else if (val_to < val_from)
        net_neg[val_from - val_to].push_back(ids_from.back());
    }

    if (ids_from.empty())
      net_neg.erase(it_neg);
    if (ids_to.empty())
      net_pos.erase(it_pos);

    // Check and remove for exact match
    check_and_remove_exact_match(std::abs(val_from - val_to));
  }
  assert(net_pos.empty() && net_neg.empty());

  return result;
}

int main() {
  std::random_device rd;
  std::mt19937 g(rd());

  std::unordered_map<std::string, int> name_to_id;
  std::vector<std::string> names;
  std::vector<long long> net;

  auto insert_name = [&](std::string const &name) -> int {
    if (not name_to_id.count(name)) {
      int id = names.size();
      names.push_back(name);
      net.push_back(0LL);
      name_to_id[name] = id;
      return id;
    }
    return name_to_id[name];
  };

  for (std::string s; std::getline(std::cin, s);) {
    std::stringstream ss(s);
    std::string name;
    std::vector<int> froms;
    int to = -1;
    long long money = 0;

    while (ss >> name) {
      if (name == "->") {
        double money_float;
        ss >> name >> money_float;
        to = insert_name(name);

        // Convert the money to 64bit integer with its value rounded down to
        // nearest cent. Operating money with integer is better because we
        // don't have to worry about weird float calculation error.
        money = money_float * 100;
        break;
      }
      froms.push_back(insert_name(name));
    }

    net[to] += money;
    std::shuffle(froms.begin(), froms.end(), g);
    for (int i = 0; i < froms.size(); ++i) {
      int from = froms[i];
      int debt = money / froms.size();
      if (i < money - debt * froms.size())
        debt += 1;
      net[from] -= debt;
    }
  }

  // Solver
  auto transactions = solve(net);

  // Pretty print with indentation
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
           names[t.from].c_str(), (int)max_from_name_len, names[t.to].c_str(),
           max_value_len, (double)t.value / 100.0);
  }

  return 0;
}

git checkout main

git branch -D code-development
git push origin --delete code-development

git branch code-development
git push --set-upstream origin code-development

echo "# use to commit a change, drive workflow execution" > workflow.driver
git add workflow.driver
git commit -m "running dev push to test workflows #0 [skip ci]"
git push

echo "# use to drive workflow" > workflow.driver
git add workflow.driver
git commit -m "running dev push to test workflows #0 [skip ci]"
git push

echo "# use to commit a change, drive workflow execution" > workflow.driver
git add workflow.driver
git commit -m "running dev push to test workflows #0"
git push

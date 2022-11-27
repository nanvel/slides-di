require 'dry/container/stub'
require 'rspec'

require './main'


RSpec.describe Enumerators::Simple do
    let(:initial) { 0 }

    subject { described_class.new(initial: initial) }

    it 'increases value by 1' do
        expect(subject.call).to eq(initial + 1)
        expect(subject.call).to eq(initial + 2)
    end
end


RSpec.describe UseCases::AddTask do
    let(:enumerator) { double('enumerator', call: 1) }
    let(:task_factory) { Factories::Task.new(enumerator: enumerator) }
    let(:tasks_repository)  { double('tasks_repository', add: nil) }
    let(:text) { 'Test text' }

    subject do
        described_class.new(
            task_factory: task_factory,
            tasks_repository: tasks_repository,
        )
    end

    it 'adds task to the repository' do
        subject.call(text)

        expect(tasks_repository).to have_received(:add).with(Models::Task) do |task|
            expect(task.priority.min?).to be_truthy
            expect(task.text).to eq(text)
        end
    end
end


RSpec.describe 'A container test' do
    let(:task) do
        Models::Task.new(
            id: 1,
            text: 'Example text.',
            priority: Models::Priority.low
        )
    end
    let(:tasks_repository) do
        double('tasks_repository', add: nil, list: [task])
    end

    subject { Container.build }

    before do
        subject.enable_stubs!
        subject.stub('todo.tasks_repository', tasks_repository)
    end

    it 'prints added task' do
        print_tasks = subject.resolve('todo.print_tasks')

        expect { print_tasks.call }.to output("- 1: Example text.\n").to_stdout
    end
end
